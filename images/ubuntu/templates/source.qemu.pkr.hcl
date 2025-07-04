variable "qemu_output_dir" {
  type = string
  default = ""
}

source "qemu" "image" {
  iso_url            = "https://cloud-images.ubuntu.com/noble/20250610/noble-server-cloudimg-amd64.img"
  iso_checksum       = "92d2c4591af9a82785464bede56022c49d4be27bde1bdcf4a9fccc62425cda43"
  output_directory   = "${var.qemu_output_dir}"
  # disk_image = true, because we use cloud image, instead of ISO image
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
