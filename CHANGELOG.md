# task_template x.y.z

## BREAKING CHANGES

<!-- * Restructured `src` directory (PR #3). -->

## NEW FUNCTIONALITY

* Added `control_methods/true_labels` component (PR #5).

* Added `methods/logistic_regression` component (PR #5).

* Added `metrics/accuracy` component (PR #5).

* Added `control_methods/random_labels` component (PR #22).

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

* `process_dataset`: also seed `np.random` when `--seed` is set (PR #22).

* `accuracy`: write `metric_values` as a list to match `metric_ids` (PR #22).

