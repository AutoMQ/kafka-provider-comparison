// Only the following vars can be customized
ami             = "ami-04c77a27ae5156100" // Ubuntu 22.04 LTS for x86_64
user            = "ubuntu"

instance_type = {
  "server"              = "r6i.large"
  "broker"              = "r6i.large"
  "client"              = "r6i.xlarge"
}

instance_cnt = {
  ## r6i.large in/out 100MB/s
  "server"              = 3
  "broker"              = 9
  "client"              = 5
}

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000
ebs_throughput = 500


