# /// script
# requires-python = ">=3.12"
# dependencies = ["lamindb==2.12.2", "pyyaml"]
# ///
"""Test resources: mouse pancreatic islet atlas.

Runs one component of every step of the benchmark on the common test dataset, so that each
component can be tested on the input it gets in the workflow: the data processor, one method
and one metric. The outputs are an example of every file format in `src/api`.

Run from the root of the repository, which needs Docker, Viash and write access to the
LaminDB instance in `.lamin/current_instance`:

    uv run scripts/create_test_resources/cxg_mouse_pancreas_atlas.py

The outputs are stored as one collection, whose uri is printed at the end. The collection
gets a new version when the outputs change; pin that version in `info.test_resources` of
`_viash.yaml`.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import lamindb as ln

sys.path.insert(0, "common/helper_functions")
import lamin_helpers as helpers  # noqa: E402


def viash_run(component, **args):
  """Run a component of this repository."""
  cmd = ["viash", "run", f"src/{component}/config.vsh.yaml", "--"]
  for name, value in args.items():
    cmd += [f"--{name}", str(value)]
  subprocess.run(cmd, cwd=helpers.REPO_ROOT, check=True)


helpers.track("scripts/create_test_resources/cxg_mouse_pancreas_atlas.py")

# the common test dataset, the same version as the test resources in `_viash.yaml`
dataset = ln.Artifact.get("NcNUHGCs1hm3sYJ70005").cache()

output_dir = Path(tempfile.mkdtemp()) / "cxg_mouse_pancreas_atlas"

# process dataset, with a seed so that rerunning this script gives the same split
viash_run(
  "data_processors/process_dataset",
  input=dataset,
  seed=123,
  output_train=output_dir / "train.anndata.zarr",
  output_test=output_dir / "test.anndata.zarr",
  output_solution=output_dir / "solution.anndata.zarr",
)

# run one method
viash_run(
  "methods/logistic_regression",
  input_train=output_dir / "train.anndata.zarr",
  input_test=output_dir / "test.anndata.zarr",
  output=output_dir / "prediction.anndata.zarr",
)

# run one metric
viash_run(
  "metrics/accuracy",
  input_prediction=output_dir / "prediction.anndata.zarr",
  input_solution=output_dir / "solution.anndata.zarr",
  output=output_dir / "score.json",
)

# store every output as an artifact, in one collection
helpers.save_collection(
  output_dir,
  ["train.anndata.zarr", "test.anndata.zarr", "solution.anndata.zarr", "prediction.anndata.zarr", "score.json"],
  key=f"resources_test/{helpers.TASK}/cxg_mouse_pancreas_atlas",
  description="Mouse pancreatic islet atlas (CELLxGENE), split into train and test cells, with one prediction and score",
)

ln.finish()
