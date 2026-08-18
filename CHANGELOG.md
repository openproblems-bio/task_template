# task_template x.y.z

## BREAKING CHANGES

<!-- * Restructured `src` directory (PR #3). -->

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

* Fixed broken documentation links in `README.md` and `CONTRIBUTING.md`, and added a quickstart to the README (PR #21).

* `run_test_local.sh` now runs as-is on the template's test resources (PR #21).

* Added a placeholder `thumbnail.svg` and scoped the common test resources to `cxg_mouse_pancreas_atlas` (PR #21).

## BUGFIXES

