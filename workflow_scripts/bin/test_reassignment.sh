#!/bin/bash

bootstrap_server=$(cat bootstrap-server.txt)

topic_name=$(kafka_2.13-3.7.0/bin/kafka-topics.sh --list --bootstrap-server $bootstrap_server | grep test-topic |head -n 1)
echo "Topic name: $topic_name"
## Example Output: Topic: test-topic-0000000-1000-7P8G9YM  TopicId: Iv2MBB4uSuqOGnVDfxoscQ PartitionCount: 1000    ReplicationFactor: 1    Configs: min.insync.replicas=1,segment.bytes=1073741824,retention.ms=86400000,flush.messages=1,max.message.bytes=10485760
replica_count=$(kafka_2.13-3.7.0/bin/kafka-topics.sh --describe --bootstrap-server $bootstrap_server --topic $topic_name | grep ReplicationFactor | awk '{print $8}')
echo "Replica count: $replica_count"

if [ "$replica_count" -eq 1 ]; then
    json_file="move1replica.json"
elif [ "$replica_count" -eq 3 ]; then
    json_file="move3replica.json"
else
    echo "Unsupported replica count: $replica_count"
    exit 1
fi

cp $json_file $json_file.updated

sed -i "s/\${REASSIGN_TOPIC}/$topic_name/g" $json_file.updated

echo "Replacement complete."

# Command to execute the partition reassignment
execute_command="kafka_2.13-3.7.0/bin/kafka-reassign-partitions.sh --bootstrap-server $bootstrap_server --reassignment-json-file $json_file.updated --execute"
# Command to verify the partition reassignment
verify_command="kafka_2.13-3.7.0/bin/kafka-reassign-partitions.sh --bootstrap-server $bootstrap_server --reassignment-json-file $json_file.updated --verify"

# Record the start time
start_time=$(date +%s)

# Execute the partition reassignment
echo "Executing partition reassignment..."
$execute_command

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Error occurred during partition reassignment. Exiting."
    exit 1
fi

# Check the reassignment status
echo "Checking reassignment status..."
while true; do
    # Execute the verify command
    output=$($verify_command)

    # Check if the output contains "Reassignment of partition xxxx is completed"
    if echo "$output" | grep -q "Reassignment of partition .* is completed"; then
        # Record the end time
        end_time=$(date +%s)
        # Calculate the elapsed time
        elapsed_time=$((end_time - start_time))
        echo "Reassignment completed in $elapsed_time seconds."
        echo "$elapsed_time" >> reassign_cost.log
        break
    else
        echo "Reassignment is still in progress..."
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ $elapsed_time -ge 1800 ]; then
        echo "Partition reassignment verification timed out after 30 minutes."
        exit 1
    fi

    # Wait for 1 second
    sleep 1
done