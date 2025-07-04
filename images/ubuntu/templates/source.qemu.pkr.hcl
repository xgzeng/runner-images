variable "qemu_output_dir" {
  type = string
  default = ""
}

locals {
  qemu_image_properties_map = {
      "ubuntu22" = {
        iso_url = "https://cloud-images.ubuntu.com/jammy/20250702/jammy-server-cloudimg-amd64.img"
        iso_sha256 = "80232fb756d0ba69d3ff4b0f717362d7cb24f55a5f1b4f63e9e09c7f6bed99d2"
      },
      "ubuntu24" = {
        iso_url = "https://cloud-images.ubuntu.com/noble/20250704/noble-server-cloudimg-amd64.img"
        iso_sha256 = "f1652d29d497fb7c623433705c9fca6525d1311b11294a0f495eed55c7639d1f"
      }
  }
  qemu_image_properties = local.qemu_image_properties_map[var.image_os]
}

source "qemu" "image" {
  iso_url            = local.qemu_image_properties.iso_url
  iso_checksum       = local.qemu_image_properties.iso_sha256
  output_directory   = var.qemu_output_dir

  # disk_image = true, because we use cloud image that boot directly, instead of ISO image
  disk_image         = true
  disk_size          = "${local.image_properties.os_disk_size_gb}G"
  format             = "qcow2"
  accelerator        = "kvm"
  headless           = true
  memory             = 4096

  # password for default user(ubuntu) is set in cloud-init
  ssh_username       = "ubuntu"
  ssh_password       = var.ssh_password
  ssh_wait_timeout = "5m"
  # shutdown_command   = "echo 'ubuntu' | sudo -S shutdown -P now"
  shutdown_command   = "sudo -- sh -c '${var.installer_script_folder}/deprovision.sh; shutdown -P now'"

  # CDROM for cloud-init
  cd_label           = "cidata"
  cd_files           = ["${path.root}/../cloud-init/meta-data"]
  cd_content         = {
    "user-data" = templatefile(abspath("${path.root}/../cloud-init/user-data.template"), {
      "password": "${var.ssh_password}"
    })
  }

#  qemuargs = [
#    ["-serial", "mon:stdio"],
#  ]
}
