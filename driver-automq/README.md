# AutoMQ Benchmark

## Requirements

- [Maven](https://maven.apache.org/install.html)
- [Terraform](https://www.terraform.io/downloads.html)
  - [Plugin: terraform-inventory](https://github.com/adammck/terraform-inventory)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [AWS CLI Tool](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Configure AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)

## Deployments

### Generate SSH Keys

Once you're all set up with AWS and have the necessary tools installed locally, you'll need to create both a public and a private SSH key at `~/.ssh/automq_aws` (private) and `~/.ssh/automq_aws.pub` (public), respectively. You can do this by running the following command:

```bash
ssh-keygen -f ~/.ssh/automq_aws
```

When prompted to enter a passphrase, simply hit `Enter` twice. Then, make sure that the keys have been created:

```bash
ls ~/.ssh/automq_aws*
```

### Deploy Infrastructure

We have a all-in-one script to deploy AutoMQ for Kafka on AWS. It will create all the necessary infrastructure and deploy the benchmarking tool. To run it, simply execute the following command:

```bash
python3 launch.py --scenario partition-reassignment --up
```

Note: You can choose the scenario you want to deploy by changing the `--scenario` parameter. Use `--help` to see all the available options.

### Destroy Infrastructure

To destroy the infrastructure, simply run the following command:

```bash
python3 launch.py --scenario partition-reassignment --down
```

