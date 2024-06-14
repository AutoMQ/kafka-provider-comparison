variable "instance_type" {
  type = map(string)
}

variable "public_key_path" {
  default = "~/.ssh/kpc_sshkey.pub"
}

variable "user" {}


variable "key_name" {
  default     = "kafka-kraft-benchmark-key"
  description = "Desired name prefix for the AWS key pair"
}

variable "instance_cnt" {
  type = map(string)
}
variable "ami" {}

variable "monitoring" {
  type    = bool
  default = true
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
    }
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-msk"
  public_key = file(var.public_key_path)

  tags = {
    Benchmark = "Openmessaging_msk"
  }
}


locals {
  subnet_ids = [
    aws_subnet.subnet_az1.id,
    aws_subnet.subnet_az2.id,
    aws_subnet.subnet_az3.id
  ]
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(local.subnet_ids, count.index % length(local.subnet_ids))
  vpc_security_group_ids = [aws_security_group.sg.id]
  count                  = var.instance_cnt["client"]

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name      = "Kafla_on_S3_Benchmark_EBS_root_client_${count.index}_msk"
      Benchmark = "Openmessaging_msk_client"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "kafka_msk_client_${count.index}"
    Benchmark = "Kafka"
  }
}

# ref: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_cluster
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "192.168.0.0/22"

  tags = {
    Name      = "Openmessaging_Benchmark_VPC_msk"
    Benchmark = "Openmessaging_msk"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "kafka" {
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

  tags = {
    Benchmark = "Openmessaging_msk"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.benchmark_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.kafka.id}"
}


data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.azs.names[0]
  cidr_block        = "192.168.0.0/24"
  vpc_id            = aws_vpc.benchmark_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Benchmark = "Kafka_Provider_Comparison_zhaoxiautomq"
  }
}

resource "aws_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.azs.names[1]
  cidr_block        = "192.168.1.0/24"
  vpc_id            = aws_vpc.benchmark_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Benchmark = "Kafka_Provider_Comparison_zhaoxiautomq"
  }
}

resource "aws_subnet" "subnet_az3" {
  availability_zone = data.aws_availability_zones.azs.names[2]
  cidr_block        = "192.168.2.0/24"
  vpc_id            = aws_vpc.benchmark_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Benchmark = "Kafka_Provider_Comparison_zhaoxiautomq"
  }
}


resource "aws_kms_key" "kms" {
  description = "example"
}


resource "aws_security_group" "sg" {
  name   = "openmessagging_benchmark_msk"
  vpc_id = aws_vpc.benchmark_vpc.id

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
    Name      = "Openmessaging_Benchmark_SecurityGroup_msk"
    Benchmark = "Openmessaging_msk"
  }
}

#   ref:https://docs.aws.amazon.com/msk/latest/developerguide/kraft-intro.html
resource "aws_msk_cluster" "mskcluster" {
  cluster_name           = "mskcluster"
  kafka_version          = "3.7.x.kraft"
  number_of_broker_nodes = 15

  broker_node_group_info {
    instance_type  = "kafka.m5.large"
    client_subnets = [
      aws_subnet.subnet_az1.id,
      aws_subnet.subnet_az2.id,
      aws_subnet.subnet_az3.id,
    ]
    storage_info {
      ebs_storage_info {
        #  Local retention time must greater than 3days. Ref: https://docs.amazonaws.cn/en_us/msk/latest/developerguide/msk-default-configuration.html
        volume_size = 8438
      }
    }
    security_groups = [aws_security_group.sg.id]
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.kms.arn
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }


  tags = {
    Name      = "Openmessaging_Benchmark_VPC_msk"
    Benchmark = "Openmessaging_msk"
  }
}


output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.mskcluster.bootstrap_brokers_tls
}


output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? aws_instance.client[0].public_ip : null
}

output "client_ids" {
  value = [for i in aws_instance.client : i.id]
}

output "user" {
  value = var.user
}

