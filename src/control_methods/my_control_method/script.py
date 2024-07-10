import anndata as ad
import sklearn.linear_model

## VIASH START
# Note: this section is auto-generated by viash at runtime. To edit it, make changes
# in config.vsh.yaml and then run `viash config inject config.vsh.yaml`.
par = {
  'input_train': 'resources_test/task_template/pancreas/train.h5ad',
  'input_test': 'resources_test/task_template/pancreas/test.h5ad',
  'output': 'output.h5ad'
}
meta = {
  'name': 'logistic_regression'
}
## VIASH END

print('Reading input files', flush=True)
input_train = ad.read_h5ad(par['input_train'])
input_test = ad.read_h5ad(par['input_test'])

print('Preprocess data', flush=True)
# ... preprocessing ...

print('Train model', flush=True)
# ... train model ...
classifier = sklearn.linear_model.LogisticRegression()
classifier.fit(input_train.obsm["X_pca"], input_train.obs["label"].astype(str))

print('Generate predictions', flush=True)
# ... generate predictions ...
obs = classifier.predict(input_test.obsm["X_pca"])

print("Write output AnnData to file", flush=True)
output = ad.AnnData(
  uns={
    'dataset_id': input_train.uns['dataset_id'],
    'method_id': meta['name']
  },
  obs={
    'label_pred': obs
  }
)
output.write_h5ad(par['output'], compression='gzip')
