## Kafka Provider Comparison

Kafka Provider Comparison (KPC) is a public Kafka comparison platform built on the OpenMessaging Benchmark code. Kafka API
It has become the de facto standard in the streaming field in recent years. Recently, many new stream systems compatible with Kafka API (hereinafter referred to as Kafka Providers) have emerged.
The intention of building this comparison platform is not to determine who is the best Kafka streaming system, but to provide a **fair**, **objective**, and **open** comparison environment to generate objective and fair Kafka assessments.
Stream Systems Comparative Report. The report includes multiple comparison dimensions such as latency, cost, elasticity, throughput, etc. Different products have different design architectures and trade-offs, which naturally lead to varying performances across these dimensions. This objective comparison is highly beneficial for users making technological selections.

## Supported Kafka Provider

* [AutoMQ](https://www.automq.com)
* [Apache Kafka](https://kafka.apache.org)

## Comparison Platform Execution Logic

All execution logic for the comparison platform is encapsulated within Github Actions, utilizing Github Actions' Workflow to initiate the comparison tasks. The execution logic for these tasks unfolds as follows:

1. When the scheduled trigger conditions are met, Github Actions initiates the Workflow.
2. The Workflow orchestrates multiple Kafka Provider Benchmark processes that run concurrently.
3. Each Benchmark Provider process consists of sequentially executed sub-stages, carried out in a specific order. Various Kafka Providers are evaluated simultaneously.
   1. Install: Initialize cloud resources on AWS using Terraform configuration files, check out code, install dependencies, and deploy Kafka via an Ansible playbook.
      Provider: This stage also includes cost calculations based on the Terraform configurations, which will contribute to the upcoming final Comparison Report.
   2. Benchmark: This phase follows the installation and is activated only after its completion. It mainly involves utilizing the Terraform output to remotely access the cloud-hosted client machine and conduct the OpenMessaging Benchmark tests.
   3. Generate Report: On the GitHub Runner machine, files containing benchmark results from cloud-based client executions are copied, the data is parsed to create the final Report, and then displayed in [issue-1](https://github.com/AutoMQ/kafka-provider-comparison/issues/1).
4. Uninstall: This phase is dependent on the Benchmark phase and is initiated upon its completion. It includes the cleanup of cloud resources, involving the deletion of both the cloud-based client machines and the cloud-based Kafka provider clusters.


## Benchmark Report Overview
A comprehensive Benchmark Report includes the following components:
- Report Generated: The generation timestamp of the report. Based on this timestamp, you can view the specific workflow details in the Github Actions of the open source repository, including how the cost was calculated, and logs from the Benchmark execution.
- Workload Configuration: Workload configuration details extracted from the OpenMessaging Benchmark's run logs. To ensure fairness in comparison, identical Workload, Producer, and Consumer configurations are used for all Kafka Providers.
- Producer Configuration: Producer settings, the same for all Kafka Providers.
- Consumer Configuration: Consumer settings, the same for all Kafka Providers.
- Topic Configuration: Topic settings, the same for all Kafka Providers.
- Replication Factor: Replication factor, the same for all Kafka Providers.
- Average Throughput: The average throughput for the entire benchmarking process is measured in MB/s.
- E2E LatencyAvg(ms): The average end-to-end latency throughout the entire benchmarking process, measured in milliseconds.
- E2E P95 Latency(ms): The 95% percentile end-to-end latency observed during the entire benchmarking process, measured in milliseconds.
- E2E P99 Latency(ms): The 99% percentile end-to-end latency recorded during the entire benchmarking process, measured in milliseconds.
- Baseline Cost: This is the baseline cost for this Kafka Provider, excluding the cost of IaaS cloud services utilized, and is measured in USD. It is calculated based on an analysis of Terraform configuration files using [Infracost](https://www.infracost.io/).
- Usage Cost: This cost represents the cloud resource usage for this Kafka Provider, measured in USD. It is calculated from Terraform configuration files and usage settings with [Infracost](https://www.infracost.io/). The usage calculations leverage data from the infracost directory. For instance, for AutoMQ, real-world production data shows that each GB of write traffic typically generates 31.25 PUTs and 12.5 GETs. Thus, costs are computed based on an assumed average write traffic of 10MB/s to estimate the number of API calls per second. Detailed explanations of this cost estimation methodology will be provided in subsequent chapters.
- Total Cost: The total cost for this Kafka Provider, measured in USD, combines both the baseline and usage costs.

## How to Contribute
Assuming your Kafka provider is named foo, the following content will be created to include foo in the comparison list:
Create a module named driver-foo in the root directory, which will contain the following key files in the /deploy/aws-cn directory:
- provision-kafka-aws.tf: Defines Terraform resources
- var.tfvars: Allows customization of machine type, disk size, and number of brokers/servers

> Tips: Currently, comparisons are only supported on aws-cn; support for additional cloud providers will be available in the future. Tests allow users to use machines of various quantities and specifications, but they must meet the minimum average throughput requirements, otherwise the results will not be displayed. Using higher machine specifications will improve performance but will also lead to increased costs.

### Standardized Workload
To ensure the fairness of comparisons, we have standardized a representative workload configuration, tail-read-500m.yaml, which supports generating a theoretical peak write throughput of 500 MB/s.

#### Workload configuration
name: 1-topic-1000-partitions-4kb-4p4c-500m
``` 
topics: 1
partitionsPerTopic: 1000
messageSize: 4096
payloadFile: "payload/payload-4Kb.data"
subscriptionsPerTopic: 1
consumerPerSubscription: 4
producersPerTopic: 4
producerRate: 128000
consumerBacklogSizeGB: 0
warmupDurationMinutes: 0
testDurationMinutes: 1
logIntervalMillis: 1000
```

#### Producer configuration
```
value.serializer: org.apache.kafka.common.serialization.ByteArraySerializer
acks: all
batch.size: 65536
bootstrap.servers: 10.0.0.120:9092,10.0.1.103:9092
key.serializer: org.apache.kafka.common.serialization.StringSerializer
linger.ms: 1
```

#### Consumer configuration
```
key.deserializer: org.apache.kafka.common.serialization.StringDeserializer
value.deserializer: org.apache.kafka.common.serialization.ByteArrayDeserializer
enable.auto.commit: true
bootstrap.servers: 10.0.0.82:9092
auto.offset.reset: earliest
```

#### Cost estimation
Estimating costs presents a challenge due to the variability in cloud service consumption. The diversity in product implementations complicates the accurate forecasting of usage costs. Nonetheless, by organizing storage solutions into specific categories and adopting baseline assumptions, we can more accurately compute these costs.

Current Kafka Provider's storage solutions, contingent upon the overarching dependent cloud services, are classified into the following categories:
- Relying on both block storage and object g storage: AutoMQ, Confluent Tiered Storage, Redpanda
- Solely dependent on object storage: StreamNative USAR, WarpStream
- Dependent solely on cloud storage: Apache Kafka®
  When analyzing storage consumption across cloud services, it's reasonable to assume that a uniform adoption of an optimized storage model would result in a similar relationship between write traffic and usage. Hence, a single infracost usage template is adequate for one storage model.

Another critical aspect of usage is the number of replicas. With the same volume of write traffic, the number of replicas significantly influences both the required storage capacity and the write traffic. For example, AutoMQ utilizes a single replica to maintain high availability, which decreases the write traffic and storage costs by two-thirds compared to Apache Kafka®. Consequently, when estimating costs, we adjust the usage expenses based on the number of replicas needed by the Kafka Provider. For instance, AutoMQ requires 6T of storage, whereas Apache Kafka® needs 18T.


### Dependent Action Secrets
- AUTOMQ_ACCESS_KEY: AWS Access Key
- AUTOMQ_SECRET_KEY: AWS Secret Key
- INFRA_COST_API_KEY:  [Infracost](https://www.infracost.io/) API Key. Obtainable from Infracost
- SSH_PRIVATE_KEY: SSH Private Key, directly embedded in secrets
- SSH_PUBLIC_KEY: SSH Public Key, directly embedded in secrets
- TF_BACKEND_BUCKET: S3 Bucket for storing Terraform State
- TF_BACKEND_KEY: The S3 Key for storing Terraform State

## Reporting cycle comparison
We plan to generate a comparison report weekly.

## TODO
- Supports unified management of Kafka Provider's templates, ansible.cfg, and similar files to avoid redundancy when adding new Kafka Providers.
- The currently supported device name uses a fixed /dev/nvme1n1, which may be inaccurate.