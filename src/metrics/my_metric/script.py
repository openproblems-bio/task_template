import pandas as pd

## VIASH START
par = {
  "de_train": "resources/neurips-2023-kaggle/de_train.parquet",
  "de_test": "resources/neurips-2023-kaggle/de_test.parquet",
  "id_map": "resources/neurips-2023-kaggle/id_map.csv",
  "output": "output.parquet",
}
## VIASH END

print('Reading input files', flush=True)
de_train = pd.read_parquet(par["de_train"])
id_map = pd.read_csv(par["id_map"])
gene_names = [col for col in de_train.columns if col not in {"cell_type", "sm_name", "sm_lincs_id", "SMILES", "split", "control", "index"}]

print('Preprocess data', flush=True)
# ... preprocessing ...

print('Train model', flush=True)
# ... train model ...

print('Generate predictions', flush=True)
# ... generate predictions ...

print('Write output to file', flush=True)
output = pd.DataFrame(
  # ... TODO: fill in data ...
  index=id_map["id"],
  columns=gene_names
).reset_index()
output.to_parquet(par["output"])
