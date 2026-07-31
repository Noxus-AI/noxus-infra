# Supply the state bucket at init time:
#
#   tofu init \
#     -backend-config="bucket=my-tfstate" \
#     -backend-config="prefix=noxus/prod/gcp-gke"
terraform {
  backend "gcs" {}
}
