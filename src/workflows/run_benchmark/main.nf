include { checkItemAllowed; paramsetsFromVariants; expandParamsets; methodMatchesParamset; checkMethodAllowed } from "${meta.resources_dir}/helper.nf"

workflow auto {
  findStates(params, meta.config)
    | meta.workflow.run(
      auto: [publish: "state"]
    )
}

// construct list of methods and control methods
methods = [
  true_labels,
  random_labels,
  logistic_regression
]

// construct list of metrics
metrics = [
  accuracy
]

// the file names of the outputs that can be stored with --store_steps
store_filenames = [
  method: "prediction.anndata.zarr",
  metric: "score.json"
]

// select the runs of a step listed in --store_steps. the output of a run is
// published at its id, so next to the outputs of the steps it was derived from.
// what a stored output is, is not to be derived from that path: it is recorded
// in `stored_outputs.yaml` in the results.
def storeStep(ch, String step, String key) {
  ch
    .filter{ id, state -> step in (state.store_steps ?: []) }
    .map{ id, state ->
      def stored_output = [
        path: id + "/" + store_filenames[step],
        step: step,
        run_id: id,
        dataset_id: state.dataset_uns.dataset_id,
        normalization_id: state.dataset_uns.normalization_id,
        method_id: state.method_id,
        paramset_id: state.paramset_name,
        paramset: state.paramset,
        metric_component: state.metric_id
      ]
      [id, state + [stored_output: stored_output, stored_file: state[key]]]
    }
}

workflow run_wf {
  take:
  input_ch

  main:

  /****************************
   * EXTRACT DATASET METADATA *
   ****************************/
  dataset_ch = input_ch
    // store join id. the id of a run is the chain of steps that led to it:
    // <dataset_id>/<method_id>/<paramset_name>/<metric_id>
    | map{ id, state -> 
      [id, state + ["_meta": [join_id: id]]]
    }

    // extract the dataset metadata
    | extract_uns_metadata.run(
      fromState: [input: "input_solution"],
      toState: { id, output, state ->
        state + [
          dataset_uns: readYaml(output.output).uns
        ]
      }
    )

  /***************************
   * RUN METHODS AND METRICS *
   ***************************/
  method_ch = dataset_ch

    // expand the channel so parameterised methods run once per paramset.
    // the paramsets are read from the --paramsets file if provided, and
    // default to the method components' info.variants.
    | flatMap { id, state ->
      def method_paramsets = state.paramsets
        ? readYaml(state.paramsets)
        : paramsetsFromVariants(methods)
      expandParamsets(id, state, method_paramsets)
    }

    // run all methods
    | runEach(
      components: methods,

      // use the 'filter' argument to only run a method on the normalisation the
      // component is asking for, to match paramset-tagged states to their method,
      // and to filter by --methods_include/--methods_exclude
      filter: { id, state, comp ->
        def norm = state.dataset_uns.normalization_id
        def pref = comp.config.info.preferred_normalization
        // if the preferred normalisation is none at all,
        // we can pass whichever dataset we want
        def norm_check = (norm == "log_cp10k" && pref == "counts") || norm == pref
        def paramset_check = methodMatchesParamset(state, comp.config.name)
        def method_check = checkMethodAllowed(
          comp.config.name,
          state.paramset_name,
          state.methods_include,
          state.methods_exclude
        )

        norm_check && paramset_check && method_check
      },

      // define a new 'id' by appending the method name and paramset name to the dataset id
      id: { id, state, comp ->
        id + "/" + comp.config.name + "/" + (state.paramset_name ?: "default")
      },

      // use 'fromState' to fetch the arguments the component requires from the overall state,
      // along with the paramset arguments (if any)
      fromState: { id, state, comp ->
        def new_args = [
          input_train: state.input_train,
          input_test: state.input_test
        ]
        if (comp.config.info.type == "control_method") {
          new_args.input_solution = state.input_solution
        }
        new_args + (state.paramset ?: [:])
      },

      // use 'toState' to publish that component's outputs to the overall state
      toState: { id, output, state, comp ->
        state + [
          method_id: comp.config.name,
          method_run_id: id,
          method_output: output.output
        ]
      }
    )

  metric_ch = method_ch

    // run all metrics
    | runEach(
      components: metrics,

      // use the 'filter' argument to only run the metrics the user asked for
      filter: { id, state, comp ->
        checkItemAllowed(
          comp.config.name,
          state.metrics_include,
          state.metrics_exclude,
          "metrics_include",
          "metrics_exclude"
        )
      },

      id: { id, state, comp ->
        id + "/" + comp.config.name
      },
      // use 'fromState' to fetch the arguments the component requires from the overall state
      fromState: [
        input_solution: "input_solution", 
        input_prediction: "method_output"
      ],
      // use 'toState' to publish that component's outputs to the overall state
      toState: { id, output, state, comp ->
        state + [
          metric_id: comp.config.name,
          metric_output: output.output
        ]
      }
    )

  score_ch = metric_ch

    // read the scores, tagged with the paramset used for the method (null for
    // control methods and methods without paramsets) and with the ids of the
    // runs that produced them, so their resource usage can be found in the trace
    | map{ id, state ->
      def score_uns = readJson(state.metric_output) + [
        paramset_id: state.paramset_name,
        paramset: state.paramset,
        metric_component: state.metric_id,
        metric_run_id: id,
        run_ids: [state.method_run_id]
      ]
      [id, state + [score_uns: score_uns]]
    }

    | joinStates { ids, states ->
      ["output", [score_uns: states.collect{it.score_uns}]]
    }

  /*******************************
   * STORE INTERMEDIATE OUTPUTS *
   *******************************/
  stored_ch = storeStep(method_ch, "method", "method_output")
    | mix(storeStep(metric_ch, "metric", "metric_output"))

  stored_ch
    | map{ id, state -> [id, [state.stored_file], [state.stored_output.path]] }
    | publishFilesProc

  stored_meta_ch = stored_ch
    | joinStates { ids, states ->
      ["output", [stored_outputs: states.collect{it.stored_output}]]
    }

  /*******************
   * GATHER METADATA *
   *******************/
  meta_ch = dataset_ch
    // only keep one of the normalization methods
    | filter{ id, state ->
      state.dataset_uns.normalization_id == "log_cp10k"
    }
    | joinStates { ids, states ->
      // gather the dataset metadata, without the normalization id
      def dataset_uns = states.collect{state ->
        def uns = state.dataset_uns.clone()
        uns.remove("normalization_id")
        uns
      }

      // gather the task info and annotate it with the commit and timestamp
      def task_info = readYaml(meta.resources_dir.resolve("_viash.yaml"))
      // commitId is null when nextflow runs from a local checkout instead of a revision
      if (workflow.commitId) {
        task_info.commit = workflow.commitId
      }
      // the launch time -- workflow.complete is only known once the run is over
      task_info.timestamp = workflow.start.toInstant()
        .truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString()

      def new_state = [
        dataset_uns: dataset_uns,
        task_info: task_info,
        _meta: states[0]._meta
      ]

      ["output", new_state]
    }

  /*********************
   * WRITE THE RESULTS *
   *********************/
  output_ch = score_ch
    | mix(meta_ch, stored_meta_ch)
    | joinStates{ ids, states ->
      def merged = states.inject([:]) { acc, m -> acc + m }

      // store the scores, dataset metadata, component configs and task info in one directory
      def results = [
        "score_uns.yaml": merged.score_uns,
        "stored_outputs.yaml": merged.stored_outputs ?: [],
        "dataset_uns.yaml": merged.dataset_uns,
        "method_configs.yaml": methods.collect{it.config},
        "metric_configs.yaml": metrics.collect{it.config},
        "task_info.yaml": merged.task_info
      ]
      def results_dir = tempDir("results")
      results.each{ filename, data ->
        results_dir.resolve(filename).write(toYamlBlob(data))
      }

      [ids[0], [output_results: results_dir, _meta: merged._meta]]
    }

  emit:
  output_ch
}
