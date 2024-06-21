#!/bin/bash
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


# This script expects the following environment variables to be set:
# - STREAMING_PROVIDER
# - CLOUD_PROVIDER

SSH_BASE_CMD="ssh -o StrictHostKeyChecking=no -i ~/.ssh/kpc_sshkey"
SCP_BASE_CMD="scp -o StrictHostKeyChecking=no -i ~/.ssh/kpc_sshkey"
SSH_HOST="$(terraform output --raw user)@$(terraform output --raw client_ssh_host)"
BOOTSTRAP_SERVER="$(terraform output --raw bootstrap_brokers)"

BENCHMARK_DIR="/opt/benchmark"

# Delete old benchmark result files
sudo rm -f /tmp/*.json
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/*.json"
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/benchmark-worker.log"
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/workflow_scripts/bin/reassign_cost.log"
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/workflow_scripts/bin/kafka_2.13-3.7.0.tgz"
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/workflow_scripts/bin/kafka_2.13-3.7.0"
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/workflow_scripts/bin/bootstrap-server.txt"


$SSH_BASE_CMD $SSH_HOST "cd $BENCHMARK_DIR/workflow_scripts/bin && sudo echo $BOOTSTRAP_SERVER >  bootstrap-server.txt"

# Execute the benchmark test
## Tips: Pay attention that driver.yaml is under /driver-${STREAMING_PROVIDER}
$SSH_BASE_CMD $SSH_HOST "cd $BENCHMARK_DIR && sudo ./bin/benchmark -d ./driver-${STREAMING_PROVIDER}/driver.yaml ./workloads/vs/fast-tail-read-500m.yaml"

$SSH_BASE_CMD $SSH_HOST "cd $BENCHMARK_DIR/workflow_scripts/bin && sudo wget -q -O kafka_2.13-3.7.0.tgz https://archive.apache.org/dist/kafka/3.7.0/kafka_2.13-3.7.0.tgz"

$SSH_BASE_CMD $SSH_HOST "cd $BENCHMARK_DIR/workflow_scripts/bin && sudo tar -zxvf kafka_2.13-3.7.0.tgz"

## test reassignment, must in current dir to execute test_reassignment
$SSH_BASE_CMD $SSH_HOST "cd $BENCHMARK_DIR/workflow_scripts/bin && sudo ./test_reassignment.sh"

# Check if new result files have been generated
TIMEOUT=7200  # 2-hour timeout
ELAPSED=0
CHECK_INTERVAL=5  # Check every 5 seconds

while [ $ELAPSED -lt $TIMEOUT ]; do
  JSON_EXISTS=$($SSH_BASE_CMD $SSH_HOST "ls $BENCHMARK_DIR/*.json" 2> /dev/null)
  LOG_EXISTS=$($SSH_BASE_CMD $SSH_HOST "ls $BENCHMARK_DIR/workflow_scripts/bin/reassign_cost.log" 2> /dev/null)

  if [ -n "$JSON_EXISTS" ] && [ -n "$LOG_EXISTS" ]; then
    echo "Benchmark results and reassign_cost.log are ready."
    break
  else
    echo "Waiting for benchmark results and reassign_cost.log..."
    sleep $CHECK_INTERVAL
    ELAPSED=$(($ELAPSED + $CHECK_INTERVAL))
  fi
done

if [ $ELAPSED -lt $TIMEOUT ]; then
  # Copy the result files to local directory when they exist
  $SCP_BASE_CMD $SSH_HOST:$BENCHMARK_DIR/*.json /tmp
  $SCP_BASE_CMD $SSH_HOST:$BENCHMARK_DIR/benchmark-worker.log /tmp
  $SCP_BASE_CMD $SSH_HOST:$BENCHMARK_DIR/workflow_scripts/bin/reassign_cost.log /tmp
else
  # Exit with an error message if the timeout is reached without results
  echo "Timeout waiting for benchmark results."
  exit 1
fi
