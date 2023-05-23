public_key_path = "~/.ssh/automq_aws-cn.pub"
region          = "cn-northwest-1"
az              = ["cn-northwest-1a", "cn-northwest-1b"]

ami             = "ami-04c77a27ae5156100" // Canonical, Ubuntu, 22.04 LTS, amd64 jammy image build on 2023-03-03
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
spot = false

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000

access_key = "${AUTOMQ_ACCESS_KEY}"
secret_key = "${AUTOMQ_SECRET_KEY}"

aws_cn = true
