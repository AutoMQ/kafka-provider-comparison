#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import argparse
import configparser
import json
import os
import subprocess
from pathlib import Path

import boto3
import yaml

ami_prefix = "dev-automq-kos-linux-aws-amd64"


def is_tool(name):
    """Check whether `name` is on PATH and marked as executable."""

    # from whichcraft import which
    from shutil import which

    return which(name) is not None


def check_tools(tools):
    """Check whether tools are available in the system"""
    for tool in tools:
        if not is_tool(tool):
            raise Exception("%s is not installed" % tool)


def get_afk_long_running_path():
    # Path object for the current file
    current_file = Path(__file__)
    # Get the directory of the current file
    return current_file.parent


def extract_info_from_terraform_output():
    tf_state_file = (
        get_afk_long_running_path().joinpath("deploy").joinpath("terraform.tfstate")
    )
    extracted_info = {}
    with open(tf_state_file) as f:
        data = json.load(f)
        for key, value in data["outputs"].items():
            extracted_info[key] = value["value"]
    return extracted_info


def create_clients():
    base_path = get_afk_long_running_path().joinpath("deploy")
    subprocess.run(args=["terraform", "init", "-upgrade"], check=True, cwd=base_path)
    subprocess.run(
        args=["terraform", "apply", "-auto-approve"], check=True, cwd=base_path
    )
    return extract_info_from_terraform_output()


def pkg_whole_project():
    base_path = get_afk_long_running_path().parent
    subprocess.run(
        args=[
            "mvn",
            "clean",
            "package",
            "-Dlicense.skip=true",
            "-Dcheckstyle.skip",
            "-DskipTests",
            "-Dspotless.check.skip",
            "-Dspotbugs.skip",
        ],
        check=True,
        cwd=base_path,
    )


def modify_amq_install_yaml(scenario, dicts):
    base_path = get_afk_long_running_path().joinpath("amq-install")
    with open(base_path.joinpath(f"{scenario}.yaml.tpl")) as tpl:
        data = yaml.safe_load(tpl)
    for key, value in dicts.items():
        update_nested_dict(data["kos"], key, value)
    with open(base_path.joinpath(f"{scenario}.yaml"), "w") as f:
        yaml.dump(data, f, default_flow_style=False)


def update_nested_dict(data, key, value):
    keys = key.split(".")
    current = data

    for k in keys[:-1]:
        if k not in current:
            current[k] = {}
        current = current[k]

    current[keys[-1]] = value


def create_and_launch_servers(scenario, terraform_output):
    base_path = get_afk_long_running_path().joinpath("amq-install")
    ak = os.environ["AWS_ACCESS_KEY_ID"]
    sk = os.environ["AWS_SECRET_ACCESS_KEY"]
    modify_amq_install_yaml(
        scenario,
        {
            "installID": terraform_output["env_id"],
            "vpcID": terraform_output["vpc_id"],
            "ec2.keyPairName": terraform_output["ssh_key_name"],
            "accessKey": ak,
            "secretKey": sk,
        },
    )
    subprocess.run(
        args=[
            f"{os.path.abspath(base_path)}/amq-installer",
            "install-kos",
            "-f",
            f"{scenario}.yaml",
        ],
        check=True,
        cwd=base_path,
    )

    output_file = base_path.joinpath("privateEndpoint.txt")
    with open(output_file) as f:
        private_endpoints = f.read().strip()
    return private_endpoints.split(",")


def change_servers_in_hosts_ini(file_path, bootstrap_servers):
    config = configparser.ConfigParser()
    config.read(file_path)
    if not config.has_section("server"):
        config.add_section("server")
    # modify servers in hosts.ini
    for server in bootstrap_servers:
        private_ip = server.split(":")[0]
        # hosts.ini does not use the standard ini format, so we have to set values like this.
        config["server"]["%s ansible_user" % private_ip] = (
            "ec2-user private_ip=%s" % private_ip
        )
    with open(file_path, "w") as f:
        # set space_around_delimiters=False to avoid adding spaces around the equal sign
        config.write(f, space_around_delimiters=False)


def launch_clients(bootstrap_servers):
    base_path = get_afk_long_running_path().joinpath("deploy")
    # modify servers in hosts.ini
    change_servers_in_hosts_ini(base_path.joinpath("hosts.ini"), bootstrap_servers)
    # deploy clients
    subprocess.run(
        args=[
            "ansible-playbook",
            "deploy.yaml",
            "-i",
            "hosts.ini",
            "--limit",
            "client",
        ],
        check=True,
        cwd=base_path,
    )


def launch_all(scenario):
    may_be_download_amq_installer()
    check_tools(["ansible-playbook", "terraform", "aws", "mvn"])
    print("=== step 1/4: package the whole project ===")
    pkg_whole_project()
    print("=== step 2/4: create VPC and clients ===")
    terraform_output = create_clients()
    print("clients info: %s" % terraform_output)
    print("=== step 3/4: create and launch servers ===")
    bootstrap_servers = create_and_launch_servers(scenario, terraform_output)
    print("servers info: %s" % bootstrap_servers)
    print("=== step 4/4: deploy and launch clients ===")
    launch_clients(bootstrap_servers)
    print("=== cluster ready now!!! ===")


def destroy_servers(scenario):
    base_path = get_afk_long_running_path().joinpath("amq-install")
    subprocess.run(
        args=[
            f"{os.path.abspath(base_path)}/amq-installer",
            "uninstall-kos",
            "-f",
            f"{scenario}.yaml",
        ],
        check=True,
        cwd=base_path,
    )


def destroy_clients():
    base_path = get_afk_long_running_path().joinpath("deploy")
    subprocess.run(
        args=["terraform", "destroy", "-auto-approve"], check=True, cwd=base_path
    )


def destroy_all(scenario):
    may_be_download_amq_installer()
    check_tools(["terraform", "aws"])
    print("=== step 1/2: destroy servers ===")
    destroy_servers(scenario)
    print("=== step 2/2: destroy clients and VPC ===")
    destroy_clients()


def may_be_download_amq_installer():
    base_path = get_afk_long_running_path().joinpath("amq-install")

    if base_path.joinpath("amq-installer").exists():
        return

    print("=== download amq-installer ===")
    if os.uname().sysname == "Darwin" and os.uname().machine == "arm64":
        url = "https://download.automq.com/automq-for-kafka/0.0.1/amq-installer_darwin_arm64.tar.gz"
    elif os.uname().sysname == "Darwin" and os.uname().machine == "x86_64":
        url = "https://download.automq.com/automq-for-kafka/0.0.1/amq-installer_darwin_amd64.tar.gz"
    elif os.uname().sysname == "Linux" and os.uname().machine == "x86_64":
        url = "https://download.automq.com/automq-for-kafka/0.0.1/amq-installer_linux_amd64.tar.gz"
    else:
        raise Exception("unsupported OS and machine type")

    subprocess.run(
        args=["curl", "-L", url, "-o", "amq-installer.tar.gz"],
        check=True,
        cwd=base_path,
    )
    subprocess.run(
        args=["tar", "-xzf", "amq-installer.tar.gz"], check=True, cwd=base_path
    )
    base_path.joinpath("amq-installer.tar.gz").unlink()

    subprocess.run(
        args=[
            f"{os.path.abspath(base_path)}/amq-installer",
            "install-dependency",
        ],
        check=True,
        cwd=base_path,
    )


if __name__ == "__main__":
    if (
        os.environ.get("AWS_ACCESS_KEY_ID") is None
        or os.environ.get("AWS_SECRET_ACCESS_KEY") is None
    ):
        raise Exception(
            "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set in the environment"
        )
    parser = argparse.ArgumentParser(description="start or destroy the whole cluster")
    parser.add_argument(
        "--scenario",
        help="benchmark scenario name",
        choices=[
            "auto-scaling",
            "catch-up-read",
            "emergency-scaling",
            "partition-reassignment",
            "tail-read",
        ],
        required=True,
    )
    parser.add_argument("--up", help="launch all", action="store_true")
    parser.add_argument("--down", help="destroy all", action="store_true")
    args, leftovers = parser.parse_known_args()
    if args.up:
        launch_all(args.scenario)
    elif args.down:
        destroy_all(args.scenario)
    else:
        parser.print_help()
