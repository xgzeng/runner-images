#!/bin/bash

IMAGE_NAME=${1:-ubuntu-24.04}

RUNTIME_IMAGE=runtime-${IMAGE_NAME}.qcow2

if [ ! -f "${RUNTIME_IMAGE}" ]; then
    qemu-img create -f qcow2 -b output/${IMAGE_NAME}/packer-build_image -F qcow2 \
		"${RUNTIME_IMAGE}"
fi

qemu-system-x86_64 -smp 4 -m 4096M -machine type=pc,accel=kvm -boot c \
	-drive "file=${RUNTIME_IMAGE},if=virtio" \
	-display none \
	-device virtio-net,netdev=user.0 \
	-netdev "user,id=user.0,hostfwd=tcp::2222-:22" \
	-serial mon:stdio
