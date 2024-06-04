// Only the following vars can be customized
ami             = "ami-04c77a27ae5156100" // Ubuntu 22.04 LTS for x86_64
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

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000
ebs_throughput = 125


