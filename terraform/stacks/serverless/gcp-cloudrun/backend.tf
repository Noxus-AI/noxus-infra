# State holds the database password, the generated keys and every secret passed
# in, so keep it in a bucket with restricted access. Supply it at init time:
#
#   tofu init \
#     -backend-config="bucket=my-tfstate" \
#     -backend-config="prefix=noxus/cloudrun"
#
# For a throwaway evaluation you can delete this file and keep state locally.
terraform {
  backend "gcs" {}
}
