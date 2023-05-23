provider "aws" {
  region = var.region
}

provider "random" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
  backend "s3" {
    ## terraform s3 backend configuration  ${TF_BACKEND_BUCKET}
    bucket = "${TF_BACKEND_BUCKET}"
    key    = "${TF_BACKEND_KEY}"
    region = "${TF_BACKEND_REGION}"
  }
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/kafka_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "kafka-kraft-benchmark-key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "ami" {}

variable "user" {}

variable "az" {
  type = list(string)
}

variable "instance_type" {
  type = map(string)
}

variable "instance_cnt" {
  type = map(string)
}

# if true, enable CloudWatch monitoring on the instances
variable "monitoring" {
  type    = bool
  default = true
}

variable "ebs_volume_type" {
  type = string
}

variable "ebs_volume_size" {
  type = number
}

variable "ebs_iops" {
  type = number
}

variable "ebs_throughput" {
  type = number
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "Openmessaging_Benchmark_VPC_${AUTOMQ_ENVID}"
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "kafka" {
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

  tags = {
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.benchmark_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.kafka.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  count                   = length(var.az)
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.benchmark_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.az, count.index)


  tags = {
    Benchmark = "Openmessaging_Benchmark_${AUTOMQ_ENVID}"
  }
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "terraform-kafka__${AUTOMQ_ENVID}"
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All ports open within the VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "Openmessaging_Benchmark_SecurityGroup_${AUTOMQ_ENVID}"
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${AUTOMQ_ENVID}"
  public_key = file(var.public_key_path)

  tags = {
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

resource "aws_instance" "server" {
  ami                    = var.ami
  instance_type          = var.instance_type["server"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["server"]

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name            = "Openmessaging_Benchmark_EBS_root_server_${count.index}_${AUTOMQ_ENVID}"
      Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
    }
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    iops        = var.ebs_iops
    throughput  = var.ebs_throughput
    tags = {
      Name                  = "Openmessaging_Benchmark_EBS_data_server_${count.index}_${AUTOMQ_ENVID}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name            = "Openmessaging_Benchmark_EC2_server_${count.index}_${AUTOMQ_ENVID}"
    Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

resource "aws_instance" "broker" {
  ami                    = var.ami
  instance_type          = var.instance_type["broker"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["broker"]

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name            = "Openmessaging_Benchmark_EBS_root_broker_${count.index}_${AUTOMQ_ENVID}"
      Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
    }
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    iops        = var.ebs_iops
    throughput  = var.ebs_throughput
    tags = {
      Name                  = "Openmessaging_Benchmark_EBS_data_broker_${count.index}_${AUTOMQ_ENVID}"
      Benchmark             = "Openmessaging_${AUTOMQ_ENVID}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name            = "Openmessaging_Benchmark_EC2_broker_${count.index}_${AUTOMQ_ENVID}"
    Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["client"]

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name      = "Kafla_on_S3_Benchmark_EBS_root_client_${count.index}_${AUTOMQ_ENVID}"
      Benchmark = "Openmessaging_${AUTOMQ_ENVID}_client"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "kafka_client_${count.index}"
    Benchmark = "Kafka"
  }
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? aws_instance.server[0].public_ip : null
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] > 0 ? aws_instance.broker[0].public_ip : null
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? aws_instance.client[0].public_ip : null
}

output "client_ids" {
  value = [for i in aws_instance.client : i.id]
}

output "env_id" {
  value = random_id.hash.hex
}

output "vpc_id" {
  value = aws_vpc.benchmark_vpc.id
}

output "ssh_key_name" {
  value = aws_key_pair.auth.key_name
}