#!/bin/bash

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

# NOTE: this script works as-is on the template's test resources.
# When adapting the template to a new task, replace 'task_template' in the
# paths below and update the arguments to match your run_benchmark workflow.

set -e

# pin the nextflow version the viash-generated config is compatible with
export NXF_VER=24.04.3

echo "Running benchmark on test data"
echo "  Make sure to run 'scripts/project/build_all_docker_containers.sh'!"

# generate a unique id
RUN_ID="testrun_$(date +%Y-%m-%d_%H-%M-%S)"
publish_dir="temp/results/${RUN_ID}"

nextflow run . \
  -main-script target/nextflow/workflows/run_benchmark/main.nf \
  -profile docker \
  -resume \
  -c common/nextflow_helpers/labels_ci.config \
  --id cxg_mouse_pancreas_atlas \
  --input_train resources_test/task_template/cxg_mouse_pancreas_atlas/train.h5ad \
  --input_test resources_test/task_template/cxg_mouse_pancreas_atlas/test.h5ad \
  --input_solution resources_test/task_template/cxg_mouse_pancreas_atlas/solution.h5ad \
  --output_state state.yaml \
  --publish_dir "$publish_dir"
