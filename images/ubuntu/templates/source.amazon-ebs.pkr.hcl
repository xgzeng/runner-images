variable "aws_access_key" {
  type = string
  default = "${env("AWS_ACCESS_KEY")}"
}

variable "aws_secret_key" {
  type = string
  default = "${env("AWS_SECRET_KEY")}"
}

locals {
  aws_image_properties_map = {
      "ubuntu22" = {
        output_ami_name = "runner-image-ubuntu-22.04"
        source_ami_name = "ubuntu/images/*/ubuntu-jammy-22.04-amd64-server-*"
      },
      "ubuntu24" = {
        output_ami_name = "runner-image-ubuntu-24.04"
        source_ami_name = "ubuntu/images/*/ubuntu-noble-24.04-amd64-server-*"
      }    
  }
  aws_image_properties = local.aws_image_properties_map[var.image_os]
}

source "amazon-ebs" "image" {
  access_key    = "${var.aws_access_key}"
  secret_key    = "${var.aws_secret_key}" 
  region        = "us-east-1"

  # result image name
  ami_name      = local.aws_image_properties.output_ami_name

  ## on-demand instance type
  # instance_type = "t3a.medium"

  ## spot instance type
  spot_instance_types = [
    "t3.medium", "t3.large", "t3a.medium", "t3a.large",
    "t4g.medium", "t4g.large", "m4.large", "m4.xlarge"
  ]
  spot_price = 0.1

  ## latest official image
  source_ami_filter {
    filters = {
      name                = local.aws_image_properties.source_ami_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"
  user_data = templatefile(abspath("${path.root}/../cloud-init/user-data.template"), {
      "password": "${var.ssh_password}"
  })

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = local.image_properties.os_disk_size_gb
  }

  # create AMI from instance take a very long time
  aws_polling {
    delay_seconds = 30
    max_attempts  = 120
  }
}
