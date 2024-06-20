variable "instance_type" {
  type = map(string)
  default = {
    "client" = "r6i.large"
  }
}

variable "public_key_path" {
  default = "~/.ssh/kpc_sshkey.pub"
}

variable "aws_cn" {
  type    = bool
  default = true
}

variable "user" {
  default = "ubuntu"
}


variable "key_name" {
  default     = "kafka-kraft-benchmark-key"
  description = "Desired name prefix for the AWS key pair"
}

variable "instance_cnt" {
  type = map(string)
  default = {
    "client" = 1
  }
}
variable "ami" {
  default = "ami-04c77a27ae5156100"
}

variable "monitoring" {
  type    = bool
  default = true
}

variable "region" {
  default = "cn-northwest-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
    }
  }

  backend "s3" {
    bucket = "${TF_BACKEND_BUCKET}"
    key    = "${TF_BACKEND_KEY}"
    region = "${TF_BACKEND_REGION}"
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
#     aws_subnet.subnet_az2.id,
#     aws_subnet.subnet_az3.id
  ]
}


#   ref:https://docs.aws.amazon.com/zh_cn/msk/latest/developerguide/create-client-iam-role.html

resource "aws_iam_role" "benchmark_role_s3" {
  name = "kafka_provider_comparison_role_s3_msk"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
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
    name = "kafka_provider_comparison_policy_msk"

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "kafka-cluster:Connect",
            "kafka-cluster:AlterCluster",
            "kafka-cluster:DescribeCluster"
          ],
          Resource = var.aws_cn ? [
            "arn:aws-cn:kafka:${var.region}:*:cluster/${aws_msk_cluster.mskcluster.cluster_name}/*"
          ] : [
            "arn:aws:kafka:${var.region}:*:cluster/${aws_msk_cluster.mskcluster.cluster_name}/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kafka-cluster:*Topic*",
            "kafka-cluster:WriteData",
            "kafka-cluster:ReadData"
          ],
          Resource = var.aws_cn ? [
            "arn:aws-cn:kafka:${var.region}:*:topic/${aws_msk_cluster.mskcluster.cluster_name}/*"
          ] : [
            "arn:aws:kafka:${var.region}:*:topic/${aws_msk_cluster.mskcluster.cluster_name}/*"
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kafka-cluster:AlterGroup",
            "kafka-cluster:DescribeGroup"
          ],
          Resource = var.aws_cn ? [
            "arn:aws-cn:kafka:${var.region}:*:group/${aws_msk_cluster.mskcluster.cluster_name}/*"
          ] : [
            "arn:aws:kafka:${var.region}:*:group/${aws_msk_cluster.mskcluster.cluster_name}/*"
          ]
        }
      ]
    })
  }

  tags = {
    Name      = "Kafka_Provider_Comparison_IAM_Role_msk"
    Benchmark = "Kafka_Provider_Comparison_msk"
  }
}

resource "aws_iam_instance_profile" "benchmark_instance_profile_msk" {
  name = "kafka_provider_comparison_instance_profile_msk"

  role = aws_iam_role.benchmark_role_s3.name

  tags = {
    Name      = "Kafka_Provider_Comparison_IAM_InstanceProfile_msk"
    Benchmark = "Kafka_Provider_Comparison_msk"
  }
}


resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(local.subnet_ids, count.index % length(local.subnet_ids))
  vpc_security_group_ids = [aws_security_group.sg.id]
  count                  = var.instance_cnt["client"]

  iam_instance_profile = aws_iam_instance_profile.benchmark_instance_profile_msk.name

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
  availability_zone       = data.aws_availability_zones.azs.names[0]
  cidr_block              = "192.168.0.0/24"
  vpc_id                  = aws_vpc.benchmark_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Benchmark = "Kafka_Provider_Comparison_zhaoxiautomq"
  }
}

// ensure it is in same zone
resource "aws_subnet" "subnet_az1_2" {
  availability_zone       = data.aws_availability_zones.azs.names[0]
  cidr_block              = "192.168.1.0/24"
  vpc_id                  = aws_vpc.benchmark_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Benchmark = "Kafka_Provider_Comparison_zhaoxiautomq"
  }
}
#
# resource "aws_subnet" "subnet_az3" {
#   availability_zone       = data.aws_availability_zones.azs.names[2]
#   cidr_block              = "192.168.2.0/24"
#   vpc_id                  = aws_vpc.benchmark_vpc.id
#   map_public_ip_on_launch = true
#   tags = {
#     Benchmark = "Kafka_Provider_Comparison_zhaoxiautomq"
#   }
# }


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
    cidr_blocks = ["192.168.0.0/22"]
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
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type  = "kafka.m5.xlarge"
    client_subnets = [
      aws_subnet.subnet_az1.id,
      aws_subnet.subnet_az1_2.id,
#       aws_subnet.subnet_az3.id,
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
    encryption_in_transit{
      client_broker                  = "PLAINTEXT"
    }
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

  ## https://github.com/hashicorp/terraform-provider-aws/issues/24914
  lifecycle {
    ignore_changes = [
      client_authentication,
    ]
  }

  tags = {
    Name      = "Openmessaging_Benchmark_VPC_msk"
    Benchmark = "Openmessaging_msk"
  }
}


output "bootstrap_brokers" {
  description = "plaintext connection host:port pairs"
  value       = aws_msk_cluster.mskcluster.bootstrap_brokers
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

