# task_template x.y.z

## BREAKING CHANGES

<!-- * Restructured `src` directory (PR #3). -->

* `run_benchmark`: replaced `--method_ids` with `--methods_include`/`--methods_exclude` and added `--metrics_include`/`--metrics_exclude` (PR #20).

## NEW FUNCTIONALITY

* Added `control_methods/true_labels` component (PR #5).

* Added `methods/logistic_regression` component (PR #5).

* Added `metrics/accuracy` component (PR #5).

## MAJOR CHANGES

* Updated `api` files (PR #5).

* Updated configs, components and CI to the latest Viash version (PR #8).

* Updated to Viash 0.9.4 (PR #12).

* Use dependencies in `openproblems-bio/openproblems` (PR #12).

## MINOR CHANGES

* Updated `README.md` (PR #5).

* `run_benchmark`: write the commit the workflow ran from and the launch time into
  `task_info.yaml`, instead of publishing `_viash.yaml` verbatim (PR #18).

* Updated to Viash 0.9.7 (PR #19).

* Updated the `common` submodule (PR #19).

## BUGFIXES

