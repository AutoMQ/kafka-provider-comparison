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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Kafka reassignment json file")
    parser.add_argument("-t", "--topic", type=str,
                        required=True, help="Topic name")
    parser.add_argument("-p", "--partition", type=str, required=True,
                        help="Two numbers separated by comma indicating the start partition and end partition")
    parser.add_argument("-n", "--node", type=int, required=True,
                        help="Node id to move the partitions to")

    args = parser.parse_args()
    topic = args.topic
    partition = range(int(args.partition.split(",")[0]), int(args.partition.split(",")[1])
                      )
    node = args.node

    reassignment = {
        "version": 1,
        "partitions": [
            {
                "topic": topic,
                "partition": p,
                "replicas": [node]
            } for p in partition
        ]
    }

    print(json.dumps(reassignment))
