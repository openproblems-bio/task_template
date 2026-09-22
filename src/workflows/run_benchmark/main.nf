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

// serialise data to a yaml file in the temp dir
def writeYamlFile(data, String filename) {
  def file = tempFile(filename)
  file.write(toYamlBlob(data))
  file
}

workflow run_wf {
  take:
  input_ch

  main:

  /****************************
   * EXTRACT DATASET METADATA *
   ****************************/
  dataset_ch = input_ch
    // store join id
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
  score_ch = dataset_ch

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
        id + "." + comp.config.name + (state.paramset_name ? "." + state.paramset_name : "")
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
          method_output: output.output
        ]
      }
    )

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
        id + "." + comp.config.name
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

    // extract the scores, tagged with the paramset used for the method
    // (null for control methods and methods without paramsets)
    | extract_uns_metadata.run(
      key: "extract_scores",
      fromState: [input: "metric_output"],
      toState: { id, output, state ->
        def uns = readYaml(output.output).uns
        uns.paramset_name = state.paramset_name
        uns.paramset = state.paramset
        state + [
          score_uns: uns
        ]
      }
    )

    // store the scores in a file
    | joinStates { ids, states ->
      ["output", [output_scores: writeYamlFile(states.collect{it.score_uns}, "score_uns.yaml")]]
    }

  /******************************
   * GENERATE OUTPUT YAML FILES *
   ******************************/
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

      // store the dataset metadata, component configs and task info in files
      def new_state = [
        output_dataset_info: writeYamlFile(dataset_uns, "dataset_uns.yaml"),
        output_method_configs: writeYamlFile(methods.collect{it.config}, "method_configs.yaml"),
        output_metric_configs: writeYamlFile(metrics.collect{it.config}, "metric_configs.yaml"),
        output_task_info: writeYamlFile(task_info, "task_info.yaml"),
        _meta: states[0]._meta
      ]

      ["output", new_state]
    }

  // merge all of the output data
  output_ch = score_ch
    | mix(meta_ch)
    | joinStates{ ids, states ->
      def mergedStates = states.inject([:]) { acc, m -> acc + m }
      [ids[0], mergedStates]
    }

  emit:
  output_ch
}
