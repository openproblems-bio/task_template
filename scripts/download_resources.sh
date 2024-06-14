#!/bin/bash

set -e

echo ">> Downloading resources"

viash run common/src/sync_resources/config.vsh.yaml -- \
  --input "s3://openproblems-data/resources_test/common/" \
  --output "resources" \
  --delete