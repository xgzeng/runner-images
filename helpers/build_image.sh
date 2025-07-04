#!/bin/bash

BUILD_NAME="ubuntu-24_04"
IMAGE_OS="ubuntu24"
BUILDER="qemu"
PACKER_VARS=""

for arg in "$@"; do
    case $arg in
        --qemu)
            BUILDER="qemu"
            shift
            ;;
        --aws)
            BUILDER="amazon-ebs"
            shift
            ;;
        --ubuntu22)
            BUILD_NAME="ubuntu-22_04"
            IMAGE_OS="ubuntu22"
            shift
            ;;
        --disk_size=*)
            DISK_SIZE="${arg#*=}"
            PACKER_VARS+=" -var os_disk_size_gb=${DISK_SIZE}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --qemu              Use QEMU builder (default)"
            echo "  --aws               Use Amazon EBS builder"
            echo "  --ubuntu22          Build Ubuntu 22.04 image"
            echo "  --disk_size=SIZE    Set disk size in GB (e.g., --disk_size=20)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Error: Unknown arguments: $arg"
            echo "Use --help to see available options."
            exit 1
            ;;
    esac
done

echo "Building ${BUILD_NAME} image with builder: ${BUILDER}"

QEMU_OUTPUT_DIR=""
if [[ ${BUILDER} == "qemu" ]]; then
  QEMU_OUTPUT_DIR=output/${BUILD_NAME}
  # check if the output directory exists
  if [ -d "${QEMU_OUTPUT_DIR}" ]; then
    # prompt user for confirmation to delete the existing output directory
    read -p "Output directory ${QEMU_OUTPUT_DIR} already exists. Do you want to delete it? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
      echo "Deleting existing output directory: ${QEMU_OUTPUT_DIR}"
      rm -r "${QEMU_OUTPUT_DIR}"
    else
      echo "Exiting without deleting the output directory."
      exit 1
    fi
  fi

  PACKER_VARS+=" -var qemu_output_dir=${QEMU_OUTPUT_DIR}"
fi

source .secret.env

export PACKER_LOG=1
export PACKER_LOG_PATH=output/packer-${BUILD_NAME}.log

packer build -only "${BUILD_NAME}.${BUILDER}.image" \
    -var "image_os=${IMAGE_OS}" ${PACKER_VARS} \
    images/ubuntu/templates

if [[ $? -ne 0 ]]; then
    echo "Packer build failed. Check the log at output/packer-${BUILD_NAME}.log for details."
    exit 1
fi

# rename output image
if [[ ${BUILDER} == "qemu" ]]; then
  timestamp=$(date +%Y%m%d-%H%M%S)
  # rename BUILD_NAME to use . as seperator
  IMAGE_NAME="runner-image-${BUILD_NAME//_/.}"
  mv ${QEMU_OUTPUT_DIR}/packer-image output/${IMAGE_NAME}_${timestamp}.qcow2
  echo "Image built successfully: output/${IMAGE_NAME}_${timestamp}.qcow2"
fi
