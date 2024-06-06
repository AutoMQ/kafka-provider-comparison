// Only the following vars can be customized
ami             = "ami-04c77a27ae5156100" // Ubuntu 22.04 LTS for x86_64
user            = "ubuntu"

instance_type = {
  "server"              = "r6i.large"
  "broker"              = "r6i.large"
  "client"              = "r6i.large"
}

instance_cnt = {
  "server"              = 3
  "broker"              = 12
  "client"              = 5
}

ebs_volume_type = "gp3"
ebs_volume_size = 1440
ebs_iops = 3000
ebs_throughput = 500
