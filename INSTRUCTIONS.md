# Instructions

This is a guide on what to do after you have created a new task repository from the template. More in depth information about how to create a new task can be found in the [OpenProblems Documentation](https://openproblems.bio/documentation/create_task/).

## Requirments

A list of required software to start developing a new task can be found in the [OpenProblems Requirements](https://openproblems.bio/documentation/create_task/requirements).

## First things first

### `_viash.yaml`

* Update the `name` field to the name of the task in snake_case.
* Update the `description` field to a short description of the task.
* Add a keyword to the `keywords` field that describes the task.
* Update the `<task_name>` in the links field to the name of the task in snake_case.

### `task_info.yaml`


* Update the `src/api/task_info.yaml` file with the information you have provided in the task issue.
* Update the `<task_name>` in the `readme` field to the name of the task.

### `common` submodule

Initialize the `common` submodule by running the following command:

```bash
scripts/init_submodule.sh
```

## Resources

The OpenProblems team has provided some test resources that can be used to test the task. These resources are stored in the `resources_test` folder. The `scripts/download_resources.sh` script can be used to download these resources.
If these resources are not sufficient, you can add more resources to the `resources_test` folder. The `scripts/download_resources.sh` script can be updated to download these resources. When using new test_resources let the OP team know so they can be added to the s3 bucket.

```bash	
scripts/download_resources.sh
```

## Next steps

### API files ([docs](https://openproblems.bio/documentation/create_task/design_api))

Update the API files in the `src/api` folder. These files define the input and output of the methods and metrics. 

### Components ([docs](https://openproblems.bio/documentation/create_task/create_components))

To create a component, you can run the respective script in the `script` directory. Before running the script make sure to update the variables `task_name`, `component_name` and `component_lang` and save the file. For additionale components ou will only need to update the `component_name` and `component_lang` variables.

```bash
scripts/add_a_control_method.sh
```

```bash
scripts/add_a_method.sh
```

```bash
scripts/add_a_metric.sh
```

For each type of component there already is a first component created that you can modify.

1. Update the `.info` fields in the  `config.vsh.yaml`.
2. Add any component specific arguments to the `config.vsh.yaml` file.
3. Add any additional reqources that are required for the component.
4. Update the docker engine image setup if additional packages are required.
5. If you know the required memory and or CPU you can adjust the nextflow `.directive.labels` field. In addition if your component requires a GPU you can add the `gpu` label to the field.
6. Update the `script.py` or `script.R` file with the code for the component.

> [!NOTE]
> You can remove the comments in the `config.vsh.yaml` file after you have updated the file.

### Testing Components ([docs](https://openproblems.bio/documentation/create_component/run_tests))

You can test the component by running the following command:

```bash
viash test /path/to/config.vsh.yaml
```

Y0u can also test all components by running the following command:

```bash
scripts/test_all_components.sh
```

It is possible to custumise the command in the above script by adding a `-q` argument to only perform the test on for example methods e.g. ` -q methods`.


## Dataset processor ([docs](https://openproblems.bio/documentation/create_task/dataset_processor))

The dataset processor is a script that removes all unnecesary info from the dataset for your task. This info is defined in the `api/file_common_dataset.yaml` file. From this filtered dataset several files are created that are used by the methods and metrics. Safeguarding data leaks and laking sure the structure of the data cannot be altered for a method or a metric.

To create the dataprocessor there is no template available. You can follow the guideline in the documentation. Store the processor in the `src/process_dataset` folder.

Be sure to update the `file_common_dataset.yaml` file with the correct information required for the methods/metrics.

> [!IMPORTANT]
> When using your own datasets please advise the openproblems team on how to add these datasets to the s3 bucket.
> As the dataset processor should make use of the `common` datasets folder in the `resources` or `resources_test` directory.

To create the resources  and test_resources for the task we will create a nextflow workflow that will process the datasets. This workflow will be created together with the openproblems team.

## Benchmarking ([docs](https://openproblems.bio/documentation/create_task/create_workflow))

When you are finished with creating your components and datset processor you can create a workflow to benchmark the components. This workflow will be created together with the openproblems team.





<!-- Add to readme 
* update _viash.yaml
* update src/api/task_info.yaml
* update scripts/download_resources
-->

<!-- #!/bin/bash

echo "This script is not supposed to be run directly."
echo "Please run the script step-by-step."
exit 1

# sync resources
scripts/download_resources.sh

# create a new component
method_id="my_metric"
method_lang="python" # change this to "r" if need be

common/create_component/create_component -- \
  --language "$method_lang" \
  --name "$method_id"

# TODO: fill in required fields in src/task/methods/foo/config.vsh.yaml
# TODO: edit src/task/methods/foo/script.py/R

# test the component
viash test src/task/methods/$method_id/config.vsh.yaml

# rebuild the container (only if you change something to the docker platform)
# You can reduce the memory and cpu allotted to jobs in _viash.yaml by modifying .platforms[.type == "nextflow"].config.labels
viash run src/task/methods/$method_id/config.vsh.yaml -- \
  ---setup cachedbuild ---verbose

# run the method (using parquet as input)
viash run src/task/methods/$method_id/config.vsh.yaml -- \
  --de_train "resources/neurips-2023-kaggle/de_train.parquet" \
  --id_map "resources/neurips-2023-kaggle/id_map.csv" \
  --output "output/prediction.parquet"

# run the method (using h5ad as input)
viash run src/task/methods/$method_id/config.vsh.yaml -- \
  --de_train_h5ad "resources/neurips-2023-kaggle/2023-09-12_de_by_cell_type_train.h5ad" \
  --id_map "resources/neurips-2023-kaggle/id_map.csv" \
  --output "output/prediction.parquet"

# run evaluation metric
viash run src/task/metrics/mean_rowwise_error/config.vsh.yaml -- \
  --de_test "resources/neurips-2023-kaggle/de_test.parquet" \
  --prediction "output/prediction.parquet" \
  --output "output/score.h5ad"

# print score on kaggle test dataset
python -c 'import anndata; print(anndata.read_h5ad("output/score.h5ad").uns)' -->