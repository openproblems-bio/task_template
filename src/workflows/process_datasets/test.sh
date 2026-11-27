#!/bin/bash

# Run this prior to executing this script:
# viash ns build --parallel --setup cachedbuild

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

set -e

DATASETS_DIR="resources_test/common"
OUTPUT_DIR="output/process_datasets_test"

if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

export NXF_VER=24.04.3

nextflow run . \
  -main-script target/nextflow/workflows/process_datasets/main.nf \
  -profile docker \
  -c common/nextflow_helpers/labels_ci.config \
  --id cxg_mouse_pancreas_atlas \
  --input "$DATASETS_DIR/cxg_mouse_pancreas_atlas/dataset.anndata.zarr" \
  --output_train '$id/train.anndata.zarr' \
  --output_test '$id/test.anndata.zarr' \
  --output_solution '$id/solution.anndata.zarr' \
  --publish_dir "$OUTPUT_DIR" \
  --output_state '$id/state.yaml'
