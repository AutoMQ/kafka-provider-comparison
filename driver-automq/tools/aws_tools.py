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
import json
import re
from typing import Generator

import boto3


def describe_scaling_activities(asg_name: str):
    as_client = boto3.client('autoscaling')
    paginator = as_client.get_paginator('describe_scaling_activities')
    page_iterator = paginator.paginate(
        AutoScalingGroupName=asg_name,
        IncludeDeletedGroups=True
    )
    for page in page_iterator:
        for activity in page['Activities']:
            yield activity


def get_all_instances_in_asg(asg_name: str) -> Generator[str, None, None]:
    '''
    :param asg_name: name of the autoscaling group
    :return: a generator of instance ids, ordered by launch time descending
    '''
    for activity in describe_scaling_activities(asg_name):
        if activity['StatusCode'] == 'Successful' and activity['Description'].startswith('Launching a new EC2 instance'):
            instance_id = re.search(
                r'Launching a new EC2 instance: (i-\w+)', activity['Description']).group(1)
            yield instance_id


def generate_cloud_watch_source(
        spot_asg_name: str, fall_back_asg_name: str, controller_ids: "list[str]", broker_ids: "list[str]",
        client_ids: "list[str]", threshold: int, detailed: bool = False):
    # TODO: colorize the metrics
    cloud_watch_source = {
        "title": "Kafka on S3 Metrics",
        "view": "timeSeries",
        "stacked": False,
        "period": 60,
        "annotations": {
            "horizontal": [
                {
                    "label": "Network Threshold ({} bytes/s)".format(threshold),
                    "value": threshold,
                    "yAxis": "left",
                }
            ]
        },
        "legend": {
            "position": "right",
        },
        "liveData": True,
        "yAxis": {
            "left": {
                "label": "Network Throughput (bytes/s)",
                "min": 0,
                "showUnits": False,
            },
            "right": {
                "label": "Broker Count",
                "min": 0,
                "showUnits": False,
            }
        },
    }

    clno = "clientNetworkOut"
    clnt = "clientNetworkThroughput"

    cni = "controllerNetworkIn"
    cno = "controllerNetworkOut"
    cnt = "controllerNetworkThroughput"
    cnta = "controllerNetworkThroughputAvg"

    sp = "Spot"
    fb = "FallBack"
    bc = "brokerCount"
    bni = "brokerNetworkIn"
    bno = "brokerNetworkOut"
    bnt = "brokerNetworkThroughput"
    bnta = "brokerNetworkThroughputAvg"
    metrics = []

    # client group
    clnt_list = []
    for i, clid in enumerate(client_ids):
        metrics.append(["AWS/EC2", "NetworkOut", "InstanceId", clid,
                        {"id": f"{clno}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append([{"id": f"{clnt}{i}", "expression": f"{clno}{i}/DIFF_TIME({clno}{i})",
                       "label": "", "visible": False}])
        clnt_list.append(f"{clnt}{i}")
    clnt_list_str = ', '.join(clnt_list)
    metrics.append([{"id": clnt, "expression": f"SUM([ {clnt_list_str} ])",
                   "label": "total network throughput of all clients", "visible": not detailed}])

    # each controller
    cnt_list = []
    for i, cid in enumerate(controller_ids):
        metrics.append(["AWS/EC2", "NetworkIn", "InstanceId", cid,
                        {"id": f"{cni}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append(["AWS/EC2", "NetworkOut", "InstanceId", cid,
                        {"id": f"{cno}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append([{"id": f"{cnt}{i}",
                         "expression": f"MAX([ {cni}{i}/DIFF_TIME({cni}{i}), {cno}{i}/DIFF_TIME({cno}{i}) ])",
                         "label": f"network throughput of controller {i}", "visible": detailed}])
        cnt_list.append(f"{cnt}{i}")
    # controller group
    cnt_list_str = ', '.join(cnt_list)
    metrics.append([{"id": cnta, "expression": f"AVG([ {cnt_list_str} ])",
                   "label": "average network throughput of each controller", "visible": True}])

    # broker count
    metrics.append(["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", spot_asg_name,
                   {"id": f"{bc}{sp}", "label": "", "stat": "Average", "yAxis": "right", "visible": False}])
    metrics.append(["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", fall_back_asg_name,
                   {"id": f"{bc}{fb}", "label": "", "stat": "Average", "yAxis": "right", "visible": False}])
    metrics.append([{"id": bc, "expression": f"{bc}{sp}+{bc}{fb}",
                   "label": "broker count", "yAxis": "right", "visible": True}])

    # # each broker
    # for i, bid in enumerate(broker_ids):
    #     metrics.append(["AWS/EC2", "NetworkIn", "InstanceId", bid,
    #                     {"id": f"{bni}{i}", "label": "", "stat": "Sum", "visible": False}])
    #     metrics.append(["AWS/EC2", "NetworkOut", "InstanceId", bid,
    #                     {"id": f"{bno}{i}", "label": "", "stat": "Sum", "visible": False}])
    #     metrics.append([{"id": f"{bnt}{i}", "expression": f"MAX([ {bni}{i}/DIFF_TIME({bni}{i}), {bno}{i}/DIFF_TIME({bno}{i}) ])",
    #                      "label": f"network throughput of broker {i}", "visible": detailed}])
    # broker group
    metrics.append(["AWS/EC2", "NetworkIn", "AutoScalingGroupName", spot_asg_name,
                    {"id": f"{bni}{sp}", "label": "", "stat": "Sum", "visible": False}])
    metrics.append(["AWS/EC2", "NetworkOut", "AutoScalingGroupName", spot_asg_name,
                    {"id": f"{bno}{sp}", "label": "", "stat": "Sum", "visible": False}])
    metrics.append(["AWS/EC2", "NetworkIn", "AutoScalingGroupName", fall_back_asg_name,
                    {"id": f"{bni}{fb}", "label": "", "stat": "Sum", "visible": False}])
    metrics.append(["AWS/EC2", "NetworkOut", "AutoScalingGroupName", fall_back_asg_name,
                    {"id": f"{bno}{fb}", "label": "", "stat": "Sum", "visible": False}])
    metrics.append(
        [{"id": bnt,
          "expression":
          f"MAX([ {bni}{sp}/DIFF_TIME({bni}{sp}), {bno}{sp}/DIFF_TIME({bno}{sp}) ]) + MAX([ {bni}{fb}/DIFF_TIME({bni}{fb}), {bno}{fb}/DIFF_TIME({bno}{fb}) ])",
          "label": "", "visible": False}])
    metrics.append([{"id": bnta, "expression": f"{bnt}/{bc}",
                   "label": "average network throughput of each broker", "visible": True}])

    metrics.sort(key=lambda m: m[-1]["visible"], reverse=True)
    cloud_watch_source["metrics"] = metrics

    return cloud_watch_source


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Generate CloudWatch Source")
    parser.add_argument("-r", "--region", type=str,
                        required=True, help="AWS region")
    parser.add_argument("-e", "--env", type=str,
                        required=True, help="Environment ID")
    parser.add_argument("-C", "--controller", type=str, action='append',
                        help="Controller instance id")
    parser.add_argument("-c", "--client", type=str, action='append',
                        help="Client instance id")
    args = parser.parse_args()

    region = args.region
    env_id = args.env
    controller_list = args.controller
    client_list = args.client
    threshold = 146800640

    spot_group_name = f"stack-kos-broker-asg-{region}-{env_id}-spot-stack-group-kos-lp-{region}-{env_id}-broker-zone-0"
    fall_back_group_name = f"stack-kos-broker-asg-{region}-{env_id}-fallback-stack-group-kos-lp-{region}-{env_id}-broker-zone-0"

    broker_list = list(reversed(list(get_all_instances_in_asg(spot_group_name)))) + \
        list(reversed(list(get_all_instances_in_asg(fall_back_group_name))))
    source = generate_cloud_watch_source(
        spot_group_name, fall_back_group_name, controller_list, broker_list, client_list, threshold, True)
    print(json.dumps(source))
