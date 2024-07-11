#!/bin/bash

set -e

echo ">> Downloading resources"

common/sync_resources/sync_resources \
  --delete
