#!/bin/bash

component_name="my_method"
component_lang="python" # change this to "r" if need be

common/create_component/create_component \
  --language "$component_lang" \
  --name "$component_name"