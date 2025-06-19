#!/bin/bash

IMAGE_NAME=${1:-ubuntu-24.04}
BUILDER=${BUILDER:-"qemu"}

echo "Building ${IMAGE_NAME} image with builder: ${BUILDER}"

EXTRA_VARS=""

if [[ ${BUILDER} == "qemu" ]]; then
  OUTPUT_DIR=output_${IMAGE_NAME}
  # check if the output directory exists
  if [ -d "${OUTPUT_DIR}" ]; then
    # prompt user for confirmation to delete the existing output directory
    read -p "Output directory ${OUTPUT_DIR} already exists. Do you want to delete it? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
      echo "Deleting existing output directory: ${OUTPUT_DIR}"
      rm -r "${OUTPUT_DIR}"
    else
      echo "Exiting without deleting the output directory."
      exit 1
    fi
  fi

  EXTRA_VARS=" -var qemu_output_dir=${OUTPUT_DIR}"
elif [[ ${BUILDER} == "amazon-ebs" ]]; then
  source .secret.env
fi

export PACKER_LOG=1
export PACKER_LOG_PATH=packer-${IMAGE_NAME}.log

packer build -var "builder=${BUILDER}" ${EXTRA_VARS} \
    images/ubuntu/templates/${IMAGE_NAME}.pkr.hcl
