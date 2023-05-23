#!/bin/bash

# This script expects the following environment variables to be set:
# - STREAMING_PROVIDER
# - CLOUD_PROVIDER

SSH_BASE_CMD="ssh -o StrictHostKeyChecking=no -i ~/.ssh/${STREAMING_PROVIDER}_${CLOUD_PROVIDER}"
SCP_BASE_CMD="scp -o StrictHostKeyChecking=no -i ~/.ssh/${STREAMING_PROVIDER}_${CLOUD_PROVIDER}"
SSH_HOST="$(terraform output --raw user)@$(terraform output --raw client_ssh_host)"
BENCHMARK_DIR="/opt/benchmark"

# Delete old benchmark result files
sudo rm -f /tmp/*.json
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/*.json"
$SSH_BASE_CMD $SSH_HOST "sudo rm -f $BENCHMARK_DIR/benchmark-worker.log"

# Execute the benchmark test
## Tips: Pay attention that driver.yaml is under /driver-${STREAMING_PROVIDER}
$SSH_BASE_CMD $SSH_HOST "cd $BENCHMARK_DIR && sudo ./bin/benchmark -d ./driver-${STREAMING_PROVIDER}/driver.yaml ./workloads/vs/fast-tail-read-500m.yaml"

# Check if new result files have been generated
TIMEOUT=7200  # 2-hour timeout
ELAPSED=0
CHECK_INTERVAL=5  # Check every 5 seconds

while [ $ELAPSED -lt $TIMEOUT ]; do
  if $SSH_BASE_CMD $SSH_HOST "ls $BENCHMARK_DIR/*.json"; then
    echo "Benchmark results are ready."
    break
  else
    echo "Waiting for benchmark results..."
    sleep $CHECK_INTERVAL
    ELAPSED=$(($ELAPSED + $CHECK_INTERVAL))
  fi
done

if [ $ELAPSED -lt $TIMEOUT ]; then
  # Copy the result files to local directory when they exist
  $SCP_BASE_CMD $SSH_HOST:$BENCHMARK_DIR/*.json /tmp
  $SCP_BASE_CMD $SSH_HOST:$BENCHMARK_DIR/benchmark-worker.log /tmp
else
  # Exit with an error message if the timeout is reached without results
  echo "Timeout waiting for benchmark results."
  exit 1
fi
