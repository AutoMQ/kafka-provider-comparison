provider "alicloud" {
  region                  = var.region
  shared_credentials_file = "~/.aliyun/config.json"
  profile                 = "default"
}

provider "random" {}

terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "1.215.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
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

variable "ebs_category" {
  type = string
}

variable "ebs_performance_level" {
  type = string
}

variable "ebs_volume_size" {
  type = number
}

variable "access_key" {}

variable "secret_key" {}

locals {
  alicloud_tags = {
    Benchmark    = "Kafka_on_S3_${random_id.hash.hex}"
    automqVendor = "automq"
  }
  cluster_id       = "Benchmark___mlCHGxHKcA"
  server_kafka_ids = { for i in range(var.instance_cnt["server"]) : i => i + 1 }
  broker_kafka_ids = { for i in range(var.instance_cnt["broker"]) : i => var.instance_cnt["server"] + i + 1 }
}

resource "alicloud_resource_manager_resource_group" "benchmark_resource_group" {
  resource_group_name = "Kafka-on-S3-Benchmark-${random_id.hash.hex}"
  display_name        = "Kafka-on-S3-Benchmark-${random_id.hash.hex}"
}

# Create a VPC to launch our instances into
resource "alicloud_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  vpc_name          = "Kafka_on_S3_Benchmark_VPC_${random_id.hash.hex}"
  tags              = local.alicloud_tags
}

# Create an internet gateway to give our subnet access to the outside world
resource "alicloud_vpc_ipv4_gateway" "benchmark_gateway" {
  vpc_id  = alicloud_vpc.benchmark_vpc.id
  enabled = true

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  ipv4_gateway_name = "Kafka_on_S3_Benchmark_Gateway_${random_id.hash.hex}"
  tags              = local.alicloud_tags
}

# Create a route table for our VPC
resource "alicloud_route_table" "benchmark_route_table" {
  vpc_id         = alicloud_vpc.benchmark_vpc.id
  associate_type = "Gateway"

  route_table_name = "Kafka_on_S3_Benchmark_Route_Table_${random_id.hash.hex}"
  tags             = local.alicloud_tags
}

resource "alicloud_route_entry" "benchmark_route_entry" {
  route_table_id        = alicloud_vpc.benchmark_vpc.route_table_id
  destination_cidrblock = "0.0.0.0/0"
  nexthop_type          = "Ipv4Gateway"
  nexthop_id            = alicloud_vpc_ipv4_gateway.benchmark_gateway.id
}

# Grant the VPC internet access on its default route table
resource "alicloud_vpc_gateway_route_table_attachment" "benchmark_gateway_attachment" {
  route_table_id  = alicloud_route_table.benchmark_route_table.id
  ipv4_gateway_id = alicloud_vpc_ipv4_gateway.benchmark_gateway.id
}

# Create a vswitch to launch our instances into
resource "alicloud_vswitch" "benchmark_vswitch" {
  count      = length(var.az)
  vpc_id     = alicloud_vpc.benchmark_vpc.id
  cidr_block = cidrsubnet(alicloud_vpc.benchmark_vpc.cidr_block, 8, count.index)
  zone_id    = element(var.az, count.index)

  vswitch_name = "Kafka_on_S3_Benchmark_Vswitch_${random_id.hash.hex}"
  tags         = local.alicloud_tags
}

# Create security group
resource "alicloud_security_group" "benchmark_security_group" {
  vpc_id = alicloud_vpc.benchmark_vpc.id

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  name              = "Kafka_on_S3_Benchmark_SG_${random_id.hash.hex}"
  tags              = local.alicloud_tags
}

resource "alicloud_security_group_rule" "benchmark_security_group_rule_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "22/22"
  security_group_id = alicloud_security_group.benchmark_security_group.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "benchmark_security_group_rule_grafana" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "3000/3000"
  security_group_id = alicloud_security_group.benchmark_security_group.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "benchmark_security_group_rule_within_vpc" {
  type              = "ingress"
  ip_protocol       = "tcp"
  port_range        = "1/65535"
  security_group_id = alicloud_security_group.benchmark_security_group.id
  cidr_ip           = "10.0.0.0/16"
}

resource "alicloud_security_group_rule" "benchmark_security_group_rule_outbound" {
  type              = "egress"
  ip_protocol       = "all"
  port_range        = "1/65535"
  security_group_id = alicloud_security_group.benchmark_security_group.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_key_pair" "benchmark_key_pair" {
  key_pair_name = "${var.key_name}-${random_id.hash.hex}"
  public_key    = file(var.public_key_path)

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  tags              = local.alicloud_tags
}

resource "alicloud_ram_policy" "benchmark_policy" {
  policy_name     = "Kafka-on-S3-Benchmark-Policy-${random_id.hash.hex}"
  policy_document = <<EOF
  {
    "Version": "1",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "oss:PutObject",
          "oss:AbortMultipartUpload",
          "oss:GetObject",
          "oss:DeleteObject"
        ],
        "Resource": [
          "acs:oss:*:*:${alicloud_oss_bucket.benchmark_bucket.bucket}",
          "acs:oss:*:*:${alicloud_oss_bucket.benchmark_bucket.bucket}/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "ecs:*"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  }
  EOF
}

resource "alicloud_ram_role" "benchmark_role" {
  name     = "Kafka-on-S3-Benchmark-Role-${random_id.hash.hex}"
  document = <<EOF
  {
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "ecs.aliyuncs.com"
          ]
        }
      }
    ],
    "Version": "1"
  }
  EOF
}

resource "alicloud_ram_role_policy_attachment" "benchmark_role_policy_attachment" {
  policy_name = alicloud_ram_policy.benchmark_policy.policy_name
  policy_type = alicloud_ram_policy.benchmark_policy.type
  role_name   = alicloud_ram_role.benchmark_role.name
}

resource "alicloud_ecs_disk" "server_data_disk" {
  count             = var.instance_cnt["server"]
  zone_id           = element(var.az, count.index % length(var.az))
  category          = var.ebs_category
  performance_level = var.ebs_performance_level
  size              = var.ebs_volume_size
  disk_name         = "Kafka_on_S3_Benchmark_EBS_data_server_${count.index}_${random_id.hash.hex}"
  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  tags = merge(local.alicloud_tags, {
    automqNodeID    = local.server_kafka_ids[count.index]
    automqClusterID = local.cluster_id
  })
}

resource "alicloud_instance" "server" {
  image_id        = var.ami
  instance_type   = var.instance_type["server"]
  key_name        = alicloud_key_pair.benchmark_key_pair.id
  vswitch_id      = element(alicloud_vswitch.benchmark_vswitch.*.id, count.index % length(var.az))
  security_groups = [alicloud_security_group.benchmark_security_group.id]
  count           = var.instance_cnt["server"]

  internet_charge_type       = "PayByTraffic"
  internet_max_bandwidth_out = "32"

  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL0"
  system_disk_size              = 20
  system_disk_name              = "Kafka_on_S3_Benchmark_EBS_root_server_${count.index}_${random_id.hash.hex}"

  role_name = alicloud_ram_role.benchmark_role.name

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  instance_name     = "Kafka_on_S3_Benchmark_ECS_server_${count.index}_${random_id.hash.hex}"
  tags = merge(local.alicloud_tags, {
    nodeID          = local.server_kafka_ids[count.index]
    automqClusterID = local.cluster_id
  })
  volume_tags = merge(local.alicloud_tags, {
    automqClusterID = local.cluster_id
  })
}

resource "alicloud_disk_attachment" "server_data_disk_attachment" {
  count       = var.instance_cnt["server"]
  instance_id = alicloud_instance.server[count.index].id
  disk_id     = alicloud_ecs_disk.server_data_disk[count.index].id
}

resource "alicloud_ecs_disk" "broker_data_disk" {
  count             = var.instance_cnt["broker"]
  zone_id           = element(var.az, count.index % length(var.az))
  category          = var.ebs_category
  performance_level = var.ebs_performance_level
  size              = var.ebs_volume_size
  disk_name         = "Kafka_on_S3_Benchmark_EBS_data_broker_${count.index}_${random_id.hash.hex}"
  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  tags = merge(local.alicloud_tags, {
    automqNodeID          = local.broker_kafka_ids[count.index]
    automqFailoverEnabled = "true"
    automqClusterID       = local.cluster_id
  })
}

resource "alicloud_instance" "broker" {
  image_id        = var.ami
  instance_type   = var.instance_type["broker"]
  key_name        = alicloud_key_pair.benchmark_key_pair.id
  vswitch_id      = element(alicloud_vswitch.benchmark_vswitch.*.id, count.index % length(var.az))
  security_groups = [alicloud_security_group.benchmark_security_group.id]
  count           = var.instance_cnt["broker"]

  internet_charge_type       = "PayByTraffic"
  internet_max_bandwidth_out = "32"

  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL0"
  system_disk_size              = 20
  system_disk_name              = "Kafka_on_S3_Benchmark_EBS_root_broker_${count.index}_${random_id.hash.hex}"

  role_name = alicloud_ram_role.benchmark_role.name

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  instance_name     = "Kafka_on_S3_Benchmark_ECS_broker_${count.index}_${random_id.hash.hex}"
  tags = merge(local.alicloud_tags, {
    nodeID          = local.broker_kafka_ids[count.index]
    automqClusterID = local.cluster_id
  })
  volume_tags = merge(local.alicloud_tags, {
    automqClusterID = local.cluster_id
  })
}

resource "alicloud_disk_attachment" "broker_data_disk_attachment" {
  count       = var.instance_cnt["broker"]
  instance_id = alicloud_instance.broker[count.index].id
  disk_id     = alicloud_ecs_disk.broker_data_disk[count.index].id
}

resource "alicloud_instance" "client" {
  image_id        = var.ami
  instance_type   = var.instance_type["client"]
  key_name        = alicloud_key_pair.benchmark_key_pair.id
  vswitch_id      = element(alicloud_vswitch.benchmark_vswitch.*.id, count.index % length(var.az))
  security_groups = [alicloud_security_group.benchmark_security_group.id]
  count           = var.instance_cnt["client"]

  internet_charge_type       = "PayByTraffic"
  internet_max_bandwidth_out = "32"

  system_disk_category          = "cloud_essd"
  system_disk_performance_level = "PL0"
  system_disk_size              = 32
  system_disk_name              = "Kafka_on_S3_Benchmark_EBS_root_client_${count.index}_${random_id.hash.hex}"

  resource_group_id = alicloud_resource_manager_resource_group.benchmark_resource_group.id
  instance_name     = "Kafka_on_S3_Benchmark_ECS_client_${count.index}_${random_id.hash.hex}"
  tags              = local.alicloud_tags
  volume_tags       = local.alicloud_tags
}


resource "alicloud_oss_bucket" "benchmark_bucket" {
  bucket        = "kafka-on-s3-benchmark-${random_id.hash.hex}"
  force_destroy = true

  tags = local.alicloud_tags
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? alicloud_instance.server[0].public_ip : null
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] > 0 ? alicloud_instance.broker[0].public_ip : null
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? alicloud_instance.client[0].public_ip : null
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server           = alicloud_instance.server,
      server_kafka_ids = local.server_kafka_ids,
      broker           = alicloud_instance.broker,
      broker_kafka_ids = local.broker_kafka_ids,
      client           = alicloud_instance.client,
      # use the first client (if exist) for telemetry
      telemetry = var.instance_cnt["client"] > 0 ? slice(alicloud_instance.client, 0, 1) : [],

      ssh_user = var.user,

      oss_endpoint = alicloud_oss_bucket.benchmark_bucket.intranet_endpoint,
      oss_region   = var.region,
      oss_bucket   = alicloud_oss_bucket.benchmark_bucket.id,
      cluster_id   = local.cluster_id,

      access_key = var.access_key,
      secret_key = var.secret_key,
      role_name  = alicloud_ram_role.benchmark_role.name,
    }
  )
  filename = "${path.module}/hosts.ini"
}
