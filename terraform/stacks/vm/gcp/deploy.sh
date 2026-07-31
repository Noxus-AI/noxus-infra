#!/usr/bin/env bash
# exit when any command fails and echo each command
set -ex

if [ ! -z "$1" ]; then
    IMAGE_NAME=$1
    gcloud compute --project=spot-public images create $IMAGE_NAME --source-image=$IMAGE_NAME --source-image-project=spot-vm-440809 --licenses projects/spot-public/global/licenses/cloud-marketplace-7d661cda482b0e1b-df1ebeb69c0ba664
fi

cd "$(dirname "$0")/mod"
zip -r tf.zip $(find . -name '*.tf')
gsutil cp tf.zip gs://noxus-terraform/gcp/tf.zip
