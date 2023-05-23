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

Example: ~/.ssh/automq_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "kafka_on_s3_benchmark_key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "az" {
  type = list(string)
}

variable "ami" {}

variable "user" {}

variable "instance_type" {
  type = map(string)
}

variable "instance_cnt" {
  type = map(string)
}

# if true, enable CloudWatch monitoring on the instances
variable "monitoring" {
  type = bool
}

# if true, use spot instances
variable "spot" {
  type = bool
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

variable "aws_cn" {
  type = bool
}

variable "access_key" {}

variable "secret_key" {}

locals {
  cluster_id       = "Benchmark___mlCHGxHKcA"
  server_kafka_ids = { for i in range(var.instance_cnt["server"]) : i => i + 1 }
  broker_kafka_ids = { for i in range(var.instance_cnt["broker"]) : i => var.instance_cnt["server"] + i + 1 }
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
resource "aws_internet_gateway" "kafka_on_s3" {
  vpc_id = aws_vpc.benchmark_vpc.id

  tags = {
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.benchmark_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.kafka_on_s3.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  count                   = length(var.az)
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.benchmark_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.az, count.index)

  tags = {
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "kafka_on_s3_${AUTOMQ_ENVID}"
  vpc_id = aws_vpc.benchmark_vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana access from anywhere
  ingress {
    from_port   = 3000
    to_port     = 3000
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

resource "aws_iam_role" "benchmark_role_s3" {
  name = "kafka_on_s3_benchmark_role_s3_${AUTOMQ_ENVID}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.aws_cn ? "ec2.amazonaws.com.cn" : "ec2.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "kafka_on_s3_benchmark_policy_${AUTOMQ_ENVID}"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:AbortMultipartUpload",
          ]
          Effect = "Allow"
          Resource = var.aws_cn ? [
            "arn:aws-cn:s3:::${aws_s3_bucket.benchmark_bucket.id}",
            "arn:aws-cn:s3:::${aws_s3_bucket.benchmark_bucket.id}/*",
            ] : [
            "arn:aws:s3:::${aws_s3_bucket.benchmark_bucket.id}",
            "arn:aws:s3:::${aws_s3_bucket.benchmark_bucket.id}/*",
          ]
        }
      ]
    })
  }

  tags = {
    Name      = "Openmessaging_Benchmark_IAM_Role_${AUTOMQ_ENVID}"
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
  }
}

resource "aws_iam_instance_profile" "benchmark_instance_profile_s3" {
  name = "kafka_on_s3_benchmark_instance_profile_s3_${AUTOMQ_ENVID}"

  role = aws_iam_role.benchmark_role_s3.name

  tags = {
    Name      = "Openmessaging_Benchmark_IAM_InstanceProfile_${AUTOMQ_ENVID}"
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

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name            = "Openmessaging_Benchmark_EBS_root_server_${count.index}_${AUTOMQ_ENVID}"
      Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
      automqVendor    = "automq"
      automqClusterID = local.cluster_id
    }
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    iops        = var.ebs_iops
    tags = {
      Name            = "Openmessaging_Benchmark_EBS_data_server_${count.index}_${AUTOMQ_ENVID}"
      Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
      automqNodeID    = local.server_kafka_ids[count.index]
      automqVendor    = "automq"
      automqClusterID = local.cluster_id
    }
  }

  iam_instance_profile = aws_iam_instance_profile.benchmark_instance_profile_s3.name

  monitoring = var.monitoring
  tags = {
    Name            = "Openmessaging_Benchmark_EC2_server_${count.index}_${AUTOMQ_ENVID}"
    Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
    nodeID          = local.server_kafka_ids[count.index]
    automqVendor    = "automq"
    automqClusterID = local.cluster_id
  }
}

resource "aws_instance" "broker" {
  ami                    = var.ami
  instance_type          = var.instance_type["broker"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["broker"]

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name            = "Openmessaging_Benchmark_EBS_root_broker_${count.index}_${AUTOMQ_ENVID}"
      Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
      automqVendor    = "automq"
      automqClusterID = local.cluster_id
    }
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    iops        = var.ebs_iops
    tags = {
      Name                  = "Openmessaging_Benchmark_EBS_data_broker_${count.index}_${AUTOMQ_ENVID}"
      Benchmark             = "Openmessaging_${AUTOMQ_ENVID}"
      automqNodeID          = local.broker_kafka_ids[count.index]
      automqFailoverEnabled = "true"
      automqVendor          = "automq"
      automqClusterID       = local.cluster_id
    }
  }

  iam_instance_profile = aws_iam_instance_profile.benchmark_instance_profile_s3.name

  monitoring = var.monitoring
  tags = {
    Name            = "Openmessaging_Benchmark_EC2_broker_${count.index}_${AUTOMQ_ENVID}"
    Benchmark       = "Openmessaging_${AUTOMQ_ENVID}"
    nodeID          = local.broker_kafka_ids[count.index]
    automqVendor    = "automq"
    automqClusterID = local.cluster_id
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["client"]

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 64
    tags = {
      Name      = "Kafla_on_S3_Benchmark_EBS_root_client_${count.index}_${AUTOMQ_ENVID}"
      Benchmark = "Openmessaging_${AUTOMQ_ENVID}_client"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "Openmessaging_Benchmark_EC2_client_${count.index}_${AUTOMQ_ENVID}"
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}_client"
  }
}

resource "aws_s3_bucket" "benchmark_bucket" {
  bucket        = "kafka-on-s3-benchmark-${AUTOMQ_ENVID}"
  force_destroy = true

  tags = {
    Name      = "Openmessaging_Benchmark_S3_${AUTOMQ_ENVID}"
    Benchmark = "Openmessaging_${AUTOMQ_ENVID}"
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

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server           = aws_instance.server,
      server_kafka_ids = local.server_kafka_ids,
      broker           = aws_instance.broker,
      broker_kafka_ids = local.broker_kafka_ids,
      client           = aws_instance.client,
      # use the first client (if exist) for telemetry
      telemetry = var.instance_cnt["client"] > 0 ? slice(aws_instance.client, 0, 1) : [],

      ssh_user = var.user,

      cloud_provider = var.aws_cn ? "aws-cn" : "aws",
      s3_region      = var.region,
      s3_bucket      = aws_s3_bucket.benchmark_bucket.id,
      aws_domain     = var.aws_cn ? "amazonaws.com.cn" : "amazonaws.com",
      cluster_id     = local.cluster_id,

      access_key = var.access_key,
      secret_key = var.secret_key,
      role_name  = aws_iam_role.benchmark_role_s3.name,
    }
  )
  filename = "${path.module}/hosts.ini"
}
