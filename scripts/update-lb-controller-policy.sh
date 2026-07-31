#!/usr/bin/env bash
# Refresh the vendored AWS Load Balancer Controller IAM policy.
#
#   scripts/update-lb-controller-policy.sh v2.13.0
#
# The policy is vendored so `terraform plan` has no network dependency. Bump it
# whenever you bump load_balancer_controller_chart_version — a controller newer
# than its policy fails at runtime with opaque AccessDenied errors on ELB calls.
set -euo pipefail

VERSION="${1:-v2.13.0}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/terraform/modules/aws/eks-addons/policies/aws-load-balancer-controller.json"
URL="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${VERSION}/docs/install/iam_policy.json"

echo "Fetching ${URL}"
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

curl -fsSL "${URL}" -o "${tmp}"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${tmp}"

mv "${tmp}" "${DEST}"
trap - EXIT

echo "Updated ${DEST} to ${VERSION}"
