public_key_path = "~/.ssh/automq_aws.pub"
region          = "cn-hangzhou"
az              = ["cn-hangzhou-k", "cn-hangzhou-j"]

ami             = "ubuntu_22_04_x64_20G_alibase_20231221.vhd"
user            = "root"

instance_type = {
  "server"              = "ecs.r7.large"
  "broker"              = "ecs.r7.large"
  "client"              = "ecs.g7.xlarge"
}

instance_cnt = {
  "server"              = 1
  "broker"              = 2
  "client"              = 2
}

ebs_category = "cloud_essd"
ebs_performance_level = "PL1"
ebs_volume_size = 20

access_key = "your_access_key"
secret_key = "your_secret_key"
