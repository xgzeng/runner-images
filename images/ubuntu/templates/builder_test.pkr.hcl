packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }

    # packer plugins install github.com/hashicorp/amazon
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_access_key" {
  type = string
  default = "${env("AWS_ACCESS_KEY")}"
}

variable "aws_secret_key" {
  type = string
  default = "${env("AWS_SECRET_KEY")}"
}

variable "os_disk_size_gb" {
  type    = number
  default = 4
}

variable "qemu_output_dir" {
  type = string
  default = "output/ubuntu-24.04"
}

variable "builder" {
  type = string
  default = "qemu"
}

# Local QEmu VM
source "qemu" "build_image" {
  iso_url            = "https://cloud-images.ubuntu.com/noble/20250610/noble-server-cloudimg-amd64.img"
  iso_checksum       = "92d2c4591af9a82785464bede56022c49d4be27bde1bdcf4a9fccc62425cda43"
  output_directory   = "${var.qemu_output_dir}"
  # disk_image = true, because we use cloud image, instead of ISO image
  disk_image         = true
  disk_size          = "${var.os_disk_size_gb}G"
  format             = "qcow2"
  accelerator        = "kvm"
  headless           = true
  memory             = 4096
  # "ubuntu" is default username for cloud image, password is set by cloud-init
  ssh_username       = "runner"
  ssh_password       = "runner"
  ssh_wait_timeout = "5m"
  shutdown_command   = "echo 'runner' | sudo -S shutdown -P now"
  # CDROM for cloud-init
  cd_files           = ["${path.root}/../cloud-init/*"]
  cd_label           = "cidata"
  qemuargs = [
    ["-serial", "mon:stdio"],
  ]
}

# Aliyun Cloud VM
source "alicloud-ecs" "build_image" {
  associate_public_ip_address = true
  image_name                  = "packer_basic"
  instance_type               = "ecs.c9i.large"
  internet_charge_type        = "PayByTraffic"
  region                      = "cn-hangzhou"
  # source_image                = "ubuntu_24_04_x64_20G_alibase_20250527.vhd"
  image_family                = "ubuntu-cloudimg-24.04"

  user_data_file              = "${path.root}/../cloud-init/user-data"
  # 'runner' is created by cloud-init user-data
  ssh_username                 = "runner"
  system_disk_mapping         {
    disk_category = "cloud_essd"
  }
}

# Amazon EC2 VM
source "amazon-ebs" "build_image" {
  access_key    = "${var.aws_access_key}"
  secret_key    = "${var.aws_secret_key}" 
  region        = "us-east-1"

  # image name
  ami_name      = "runner-image-ubuntu-24.04"
  # instance_type = "t3.medium"
  instance_type = "t2.micro"

  # latest official image
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  user_data_file = "${path.root}/../cloud-init/user-data"
  # runner: default user set by cidata
  ssh_username = "runner"

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 30
  }
}

build {
  sources = ["source.${var.builder}.build_image"]
}
