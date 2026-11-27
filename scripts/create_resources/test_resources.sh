#!/bin/bash

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

# # remove this when you have implemented the script
# echo "TODO: replace the commands in this script with the sequence of components that you need to run to generate test_resources."
# echo "  Inside this script, you will need to place commands to generate example files for each of the 'src/api/file_*.yaml' files."
# exit 1

set -e

RAW_DATA=resources_test/common
DATASET_DIR=resources_test/task_template

mkdir -p $DATASET_DIR

# process dataset
viash run src/data_processors/process_dataset/config.vsh.yaml -- \
  --input $RAW_DATA/cxg_mouse_pancreas_atlas/dataset.anndata.zarr \
  --output_train $DATASET_DIR/cxg_mouse_pancreas_atlas/train.anndata.zarr \
  --output_test $DATASET_DIR/cxg_mouse_pancreas_atlas/test.anndata.zarr \
  --output_solution $DATASET_DIR/cxg_mouse_pancreas_atlas/solution.anndata.zarr

# run one method
viash run src/methods/logistic_regression/config.vsh.yaml -- \
    --input_train $DATASET_DIR/cxg_mouse_pancreas_atlas/train.anndata.zarr \
    --input_test $DATASET_DIR/cxg_mouse_pancreas_atlas/test.anndata.zarr \
    --output $DATASET_DIR/cxg_mouse_pancreas_atlas/prediction.anndata.zarr

# run one metric
viash run src/metrics/accuracy/config.vsh.yaml -- \
    --input_prediction $DATASET_DIR/cxg_mouse_pancreas_atlas/prediction.anndata.zarr \
    --input_solution $DATASET_DIR/cxg_mouse_pancreas_atlas/solution.anndata.zarr \
    --output $DATASET_DIR/cxg_mouse_pancreas_atlas/score.json

# write manual state.yaml. this is not actually necessary but you never know it might be useful
cat > $DATASET_DIR/cxg_mouse_pancreas_atlas/state.yaml << HERE
id: cxg_mouse_pancreas_atlas
train: !file train.anndata.zarr
test: !file test.anndata.zarr
solution: !file solution.anndata.zarr
prediction: !file prediction.anndata.zarr
score: !file score.json
HERE

# only run this if you have access to the openproblems-data bucket
aws s3 sync --profile op \
  "$DATASET_DIR" s3://openproblems-data/resources_test/task_template \
  --delete --dryrun
