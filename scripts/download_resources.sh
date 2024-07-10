#!/bin/bash

set -e

echo ">> Downloading resources"

common/sync_resources/sync_resources \
  --delete

# After finishing the task and the task specific test_resources are uploaded to s3, uncomment:
# common/sync_resources/sync_resources \
#   --input "s3://openproblems-data/resources_test/<task_name>/" \
#   --output "resources_test/<task_name>" \
#   --delete