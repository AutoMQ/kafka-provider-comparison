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

import re
import json

log_file_path = "debug3.output"
output_file_path = "/tmp/extracted_data"

# Define regex patterns
kafka_benchmark_driver_pattern = r'\[.*?\] INFO Benchmark - Initialized Kafka benchmark driver with common config: \{(.*?)\}, producer config: \{(.*?)\}, consumer config: \{(.*?)\}, topic config: \{(.*?)\}, replicationFactor: (\d+)'
workloads_pattern = r'Workloads: \{(.*?)\}'

# Read log file
with open(log_file_path, 'r') as file:
    log_content = file.read()

start_traffic_index = log_content.find("Starting benchmark traffic")

if start_traffic_index != -1:
    end_of_line_index = log_content.find('\n', start_traffic_index)
    if end_of_line_index != -1:
        start_index = end_of_line_index + 1
        log_content = log_content[start_index:]
    else:
        print("Reached the end of the line after 'Starting benchmark traffic'.")
        log_content = log_content[start_traffic_index:]
else:
    print("The string 'Starting benchmark traffic' was not found.")
    sys.exit(1)


workloads_match = re.search(workloads_pattern, log_content, re.DOTALL)
if workloads_match:
    workloads_str = workloads_match.group(1).strip()
else:
    workloads_str = "Not found"


def extract_workload_config(config):
    def get_value(key):
        start_index = config.find(f'"{key}"') + len(key) + 4
        end_index = config.find(',', start_index)
        if end_index == -1:
            end_index = config.find('\n', start_index)
        value = config[start_index:end_index].strip()
        if value.endswith(','):
            value = value[:-1]
        return value.replace('"', '')

    keys = [
        "name", "topics", "partitionsPerTopic", "partitionsPerTopicList", "randomTopicNames",
        "keyDistributor", "messageSize", "useRandomizedPayloads", "randomBytesRatio",
        "randomizedPayloadPoolSize", "payloadFile", "subscriptionsPerTopic", "producersPerTopic",
        "producersPerTopicList", "consumerPerSubscription", "producerRate", "producerRateList",
        "consumerBacklogSizeGB", "backlogDrainRatio", "testDurationMinutes", "warmupDurationMinutes",
        "logIntervalMillis"
    ]

    workload_dict = {}
    for key in keys:
        value = get_value(key)
        if value == 'null':
            value = None
        elif value == 'true':
            value = True
        elif value == 'false':
            value = False
        else:
            try:
                value = int(value)
            except ValueError:
                try:
                    value = float(value)
                except ValueError:
                    pass
        workload_dict[key] = value

    return workload_dict


if workloads_str != "Not found":
    workloads = extract_workload_config(workloads_str)
else:
    workloads = "Not found"

# Extract KafkaBenchmarkDriver information
kafka_benchmark_driver_match = re.search(kafka_benchmark_driver_pattern, log_content, re.DOTALL)
if kafka_benchmark_driver_match:
    common_config = kafka_benchmark_driver_match.group(1).strip()
    producer_config = kafka_benchmark_driver_match.group(2).strip()
    consumer_config = kafka_benchmark_driver_match.group(3).strip()
    topic_config = kafka_benchmark_driver_match.group(4).strip()
    replicationFactor = kafka_benchmark_driver_match.group(5).strip()
else:
    common_config = "Not found"
    producer_config = "Not found"
    consumer_config = "Not found"
    topic_config = "Not found"
    replicationFactor = "Not found"

# Calculate average throughput
throughput_pattern = r'WorkloadGenerator - Pub rate \d+\.\d+ msg/s \/ (\d+\.\d+) MB/s'
throughput_matches = re.findall(throughput_pattern, log_content)

average_latency_pattern = r'WorkloadGenerator.*?Pub Latency \(ms\) avg:\s*([\d.]+)'
average_latency_matches = re.findall(average_latency_pattern, log_content, re.DOTALL)

p99_latency_pattern = r'WorkloadGenerator.*?Pub Latency \(ms\) avg:.*?99%: ([\d.]+)'
p99_latency_matches = re.findall(p99_latency_pattern, log_content, re.DOTALL)

average_throughput = round(sum(float(tp) for tp in throughput_matches) / len(throughput_matches) if throughput_matches else 0, 2)
average_pub_latency = round(sum(float(lat) for lat in average_latency_matches) / len(average_latency_matches) if average_latency_matches else 0, 2)
p99_pub_latency = round(sum(float(lat) for lat in p99_latency_matches) / len(p99_latency_matches), 2) if p99_latency_matches else 0.00

print("Throughput matches:", throughput_matches)
print("Average latency matches:", average_latency_matches)
print("P99 latency matches:", p99_latency_matches)

# Prepare data for output
extracted_data = {
    "workload_config": workloads,
    "producer_config": producer_config,
    "consumer_config": consumer_config,
    "topic_config": topic_config,
    "replication_factor": replicationFactor,
    "average_throughput": average_throughput,
    "average_pub_latency": average_pub_latency,
    "p99_pub_latency": p99_pub_latency
}

# Write to output file
with open(output_file_path, 'w') as outfile:
    json.dump(extracted_data, outfile, indent=4)

# Print the extracted data for verification
print(json.dumps(extracted_data, indent=4))
