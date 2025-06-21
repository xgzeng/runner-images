#!/bin/bash

IMAGE_NAME=${1:-ubuntu-24.04}
echo "Building image: ${IMAGE_NAME}"

OUTPUT_DIR=output/${IMAGE_NAME}

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

export PACKER_LOG=1
export PACKER_LOG_PATH=output/packer-${IMAGE_NAME}.log

packer build -var "output_dir=${OUTPUT_DIR}" \
    images/ubuntu/templates/${IMAGE_NAME}.pkr.hcl
