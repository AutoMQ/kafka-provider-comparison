public_key_path = "~/.ssh/kafka_aws-cn.pub"
region          = "cn-northwest-1"
az              = ["cn-northwest-1a", "cn-northwest-1b"]
ami             = "ami-04c77a27ae5156100" // Ubuntu 22.04 LTS for x86_64
// ami = "ami-08133f9f7ea98ef23" Ubuntu 22.04 LTS for arm64
user            = "ubuntu"

instance_type = {
  "server"              = "r6i.large"
  "broker"              = "r6i.large"
  "client"              = "m6i.xlarge"
}

instance_cnt = {
  "server"              = 1
  "broker"              = 2
  "client"              = 2
}

monitoring = true

ebs_volume_type = "gp3"
ebs_volume_size = 2048
ebs_iops = 3000
ebs_throughput = 125
