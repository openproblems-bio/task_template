#!/bin/bash

set -e

echo ">> Downloading resources"

viash run common/src/sync_resources/config.vsh.yaml -- \
  --input "s3://openproblems-bio/public/neurips-2023-competition/workflow-resources/" \
  --output "resources" \
  --delete