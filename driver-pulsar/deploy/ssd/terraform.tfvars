public_key_path = "~/.ssh/pulsar_aws.pub"
region          = "cn-northwest-1"
az              = "cn-northwest-1a"
ami             = "ami-04c77a27ae5156100" // Ubuntu 22.04 LTS

instance_types = {
  "pulsar"     = "i3en.xlarge"
  "zookeeper"  = "i3en.xlarge"
  "client"     = "m6i.2xlarge"
  "prometheus" = "i3en.large"
}

num_instances = {
  "client"     = 4
  "pulsar"     = 3
  "zookeeper"  = 3
  "prometheus" = 0
}
