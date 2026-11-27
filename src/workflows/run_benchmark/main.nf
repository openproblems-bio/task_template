include { checkItemAllowed; paramsetsFromVariants; expandParamsets; methodMatchesParamset; checkMethodAllowed; readTaskResources } from "${meta.resources_dir}/helper.nf"

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

// which methods are run on a dataset: only on the normalisation the component
// is asking for, only for its own paramsets, and only if allowed by
// --methods_include/--methods_exclude
method_filter = { id, state, comp ->
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
}

// which metrics are run on a prediction: the ones the user asked for
metric_filter = { id, state, comp ->
  checkItemAllowed(
    comp.config.name,
    state.metrics_include,
    state.metrics_exclude,
    "metrics_include",
    "metrics_exclude"
  )
}

// the id of a run is the chain of steps that led to it:
// <dataset_id>/<method_id>/<paramset_name>/<metric_id>
method_run_id = { id, state, comp ->
  id + "/" + comp.config.name + "/" + (state.paramset_name ?: "default")
}
metric_run_id = { id, state, comp ->
  id + "/" + comp.config.name
}

// the runs of a step that will be attempted: one per component that passes the
// filter. what a run is, is recorded here rather than derived from its id.
def attemptedRuns(ch, String step, List components, Closure filter, Closure run_id) {
  ch.flatMap{ id, state ->
    components
      .findAll{ comp -> filter(id, state, comp) }
      .collect{ comp ->
        def new_id = run_id(id, state, comp)
        def run = [
          run_id: new_id,
          step: step,
          dataset_id: state.dataset_uns.dataset_id,
          normalization_id: state.dataset_uns.normalization_id,
          method_id: step == "method" ? comp.config.name : state.method_id,
          paramset_id: state.paramset_name,
          paramset: state.paramset,
          metric_component: step == "metric" ? comp.config.name : null
        ]
        [new_id, [run: run]]
      }
  }
}

// the runs of a step that finished, with the resources they used. if the step
// is listed in --store_steps, the output of a run is published at its id, so
// next to the outputs of the steps it was derived from.
def finishedRuns(ch, String step, String key) {
  ch.map{ id, state ->
    def run = [run_id: id, resources: readTaskResources(state[key])]
    if (step in (state.store_steps ?: [])) {
      run.output = id + "/" + store_filenames[step]
    }
    [id, [run: run, output_file: state[key]]]
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
  paramset_ch = dataset_ch

    // expand the channel so parameterised methods run once per paramset.
    // the paramsets are read from the --paramsets file if provided, and
    // default to the method components' info.variants.
    | flatMap { id, state ->
      def method_paramsets = state.paramsets
        ? readYaml(state.paramsets)
        : paramsetsFromVariants(methods)
      expandParamsets(id, state, method_paramsets)
    }

  method_ch = paramset_ch

    // run all methods
    | runEach(
      components: methods,
      filter: method_filter,
      id: method_run_id,

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

      filter: metric_filter,
      id: metric_run_id,

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

  /*******************
   * RECORD THE RUNS *
   *******************/
  attempted_ch = attemptedRuns(paramset_ch, "method", methods, method_filter, method_run_id)
    | mix(attemptedRuns(method_ch, "metric", metrics, metric_filter, metric_run_id))
    | joinStates { ids, states ->
      ["output", [attempted_runs: states.collect{it.run}]]
    }

  finished_ch = finishedRuns(method_ch, "method", "method_output")
    | mix(finishedRuns(metric_ch, "metric", "metric_output"))

  // store the outputs of the steps listed in --store_steps. the process that
  // does so gets its own tag, so its trace is not mistaken for that of the run
  finished_ch
    | filter{ id, state -> state.run.output }
    | map{ id, state -> ["store:" + id, [state.output_file], [state.run.output]] }
    | publishFilesProc

  finished_runs_ch = finished_ch
    | joinStates { ids, states ->
      ["output", [finished_runs: states.collect{it.run}]]
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
    | mix(meta_ch, attempted_ch, finished_runs_ch)
    | joinStates{ ids, states ->
      def merged = states.inject([:]) { acc, m -> acc + m }

      // a run that was attempted but did not finish, failed
      def finished_runs = (merged.finished_runs ?: []).collectEntries{ [it.run_id, it] }
      def runs = (merged.attempted_runs ?: []).collect{ run ->
        def finished = finished_runs[run.run_id]
        run + (finished ? [status: "succeeded"] + finished : [status: "failed"])
      }

      // store the scores, runs, dataset metadata, component configs and task info in one directory
      def results = [
        "score_uns.yaml": merged.score_uns,
        "runs.yaml": runs,
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
