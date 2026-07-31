# State backend is left unconfigured so this stack can be initialised against
# whatever bucket you already run. Supply it at init time:
#
#   tofu init \
#     -backend-config="bucket=my-tfstate" \
#     -backend-config="key=noxus/prod/aws-eks.tfstate" \
#     -backend-config="region=eu-west-1" \
#     -backend-config="use_lockfile=true"
#
# Or drop a backend.hcl next to this file and use -backend-config=backend.hcl.
terraform {
  backend "s3" {}
}
