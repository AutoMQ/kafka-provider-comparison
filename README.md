[English](README.md) | [简体中文](README_zh.md)
![](images/kpc_banner.png)

## Kafka Provider Comparison

Kafka Provider Comparison (KPC) is a public Kafka comparison platform built on the code of the [OpenMessaging Benchmark](https://github.com/openmessaging/benchmark).

The Kafka API has become the de facto standard in the streaming domain. In recent years, many new streaming systems compatible with the Kafka API (hereinafter referred to as Kafka Providers) have emerged. The purpose of building this comparison platform is not to determine the best Kafka streaming system, but to provide a **fair**, **objective**, and **open** comparison environment to generate objective and fair Kafka streaming system comparison reports. The comparison reports will include multiple comparison dimensions, such as latency, cost, elasticity, throughput, and more. Different products have different design architectures and trade-offs, and naturally, they will perform differently in various comparison dimensions. This objective comparison result will be very helpful for users in making technical selections.

## Supported Kafka Providers

* [AutoMQ](https://www.automq.com)
* [Apache Kafka](https://kafka.apache.org)
* [Amazon MSK](https://docs.amazonaws.cn/msk/index.html)

## Comparison Platform Execution Logic

All execution logic of the comparison platform is encapsulated in GitHub Actions, and comparison tasks are triggered through GitHub Actions Workflow. The execution logic of the comparison tasks is as follows:

1. GitHub Actions meet the scheduled trigger conditions and trigger the Workflow execution.
2. The Benchmark processes of multiple Kafka Providers included in the Workflow will be executed in parallel.
3. Each Benchmark Provider process includes the following sequential sub-stages, executed in order. Different Kafka Providers will be evaluated simultaneously.
   1. Install: Initialize cloud resources on AWS according to the Terraform configuration file, check out the code, install dependencies, and then use the Ansible playbook to install the Kafka Provider. This stage will also calculate the cost based on the Terraform configuration file, as part of the final Comparison Report.
   2. Benchmark: This stage depends on the Install stage and will be triggered after its completion. This stage mainly uses the information from the Terraform Output to remotely log in to the cloud Client machine and execute the OpenMessaging Benchmark test.
   3. Generate Report: The Benchmark result files executed on the cloud Client will be copied to the GitHub Runner machine, the content will be parsed to generate the final Report content, and displayed in [issue-1](https://github.com/AutoMQ/kafka-provider-comparison/issues/1)
   4. Uninstall: This stage depends on the Benchmark stage and will be triggered after its completion. This stage will clean up cloud resources, including deleting the cloud Client machine and the Kafka Provider cluster on the cloud.

## Benchmark Report Description

A complete Benchmark Report will include the following content:
- Report Generated: The generation time of the Report. Based on this generation time, you can see the specific Workflow execution details from the GitHub Actions of the open-source repository, including how the cost is calculated, the Benchmark output logs, etc.
- Workload Configuration: The Workload configuration information extracted from the OpenMessaging Benchmark run logs. To ensure the fairness of the comparison, we will use the exact same Workload, Producer, and Consumer configuration for all Kafka Providers.
- Producer Configuration: Producer configuration, the Producer configuration of all Kafka Providers is the same.
- Consumer Configuration: Consumer configuration, the Consumer configuration of all Kafka Providers is the same.
- Topic Configuration: Topic configuration, the Topic configuration of all Kafka Providers is the same.
- Replication Factor: Replication factor, the replication factor of all Kafka Providers is the same.
- Average Throughput: The average throughput during the entire Benchmark process, in MB/s.
- Pub Latency (ms) avg: The average publish latency during the entire Benchmark process, in ms.
- Pub Latency (ms) P99: The P99 publish latency during the entire Benchmark process, in ms.
- E2E LatencyAvg(ms): The average end-to-end latency during the entire Benchmark process, in ms.
- E2E P95 Latency(ms): The P95 end-to-end latency during the entire Benchmark process, in ms.
- E2E P99 Latency(ms): The P99 end-to-end latency during the entire Benchmark process, in ms.
- Baseline Cost: The baseline cost of the Kafka Provider (excluding the usage cost of IaaS cloud services), in USD. Based on [Infracost](https://www.infracost.io/), the cost is calculated by analyzing the Terraform configuration file.
- Usage Cost: The cloud resource usage cost of the Kafka Provider, in USD. Based on [Infracost](https://www.infracost.io/), the cost is calculated by analyzing the Terraform configuration file and usage configuration. The usage is calculated based on the infracost usage in the `infracost` directory. For example, for AutoMQ, we calculate the cost based on the average write throughput of 10MB/s, with 31.25 PUTs and 12.5 GETs per GB of write throughput. The cost estimation logic will be explained in detail in the following chapters.
- Total Cost: The total cost of the Kafka Provider, in USD. The value is equal to the baseline cost plus the usage cost.

## How to Contribute

Assuming your Kafka provider is named `foo`, you will create the following content to include `foo` in the comparison list:
Create a `driver-foo` module in the root directory, and the `/deploy/aws-cn` directory of this module must include the following key files:
- var.tfvars: By default, to ensure the fixed workload and production/consumption mode, we only open the following values for customization. If these configurations are not suitable for your Kafka Provider, you can submit a new PR and explain which new values need to be opened and the reasons.
- deploy.yaml: The Ansible playbook configuration file for deploying the specific Kafka Provider.
- cost_explanation.md: A document explaining how the cost is calculated. Different Kafka Providers have different implementations, leading to significant differences in the usage of some computing and storage services. To ensure fairness and openness, please provide a detailed explanation of the cost usage calculation logic. This part of the explanation can refer to the files in the `cost-explanation` directory of the project.
- infracost usage config yaml: In the root directory of infracost, we provide a default `template-medium-500m` template file, which is also the default usage configuration file for infracost medium scale. You can modify this file according to the actual situation of your Kafka Provider to more accurately calculate the usage cost. And publicly explain these modifications in `cost-explanation/foo.md`.

After completing the above steps, you need to add a new job in the three files under `.github/workflows` following the pattern of other Kafka Providers to ensure that the Workflow can execute the Benchmark process of your Kafka Provider when it runs on a schedule. If you have any questions about how to contribute, feel free to submit an issue under this project or join our [Slack](https://join.slack.com/t/automq/shared_invite/zt-29h17vye9-thf31ebIVL9oXuRdACnOIA) channel for discussion.

You can fork our code and test it locally. When you are satisfied with the test, you can submit a PR to our repository. We will review and merge your PR after receiving it. After merging, we will check the accuracy of your code execution in our workflow. If there are any issues, we will provide feedback on the PR and temporarily disable the execution and comparison of your Kafka Provider in the workflow (for new Kafka providers) or revert to the previous version.

> Tips: Currently, only comparisons in the cn-northwest-1 region of AWS China are supported. More cloud providers and regions will be supported in the future. The test allows users to use different numbers and specifications of machines. Using higher machine specifications will improve performance but also increase costs.

### How to Contribute a Non-Open-Source Kafka Provider

KPC also supports comparisons of non-open-source Kafka Providers. If your Kafka Provider is not open-source, you can provide a basic image that is encrypted or obfuscated to contribute a new Kafka Provider for deployment and testing in our environment. For Kafka Providers that are not open-source and do not provide images, such as Confluent/Aiven, we will use the Terraform provider they provide for deployment.

### Fixed Workload Configuration

To ensure the fairness of the comparison, we have fixed a representative Workload, Producer, and Consumer configuration [tail-read-100m.yaml](workloads/vs/fast-tail-read-100m.yaml). This configuration supports generating a theoretical peak write throughput of 100 MB/s.

### Cost Estimation

#### Challenges and Solutions of Cost Estimation

The cost of fixed-scale cloud services can be clearly calculated. The challenge of cost estimation lies in the estimation of cloud service usage. Cloud services measure and charge for different services based on usage, such as API calls and storage space for S3. Different products have different implementations, making usage cost estimation very challenging. To ensure accurate and fair estimation, we will provide a markdown file named after the Kafka provider in the driver directory of each Kafka Provider to explain how the cost is calculated. Different Kafka Providers have different implementations, leading to significant differences in the usage of some computing and storage services. To ensure fairness and openness, we will ensure that all Kafka providers provide detailed cost calculation logic for computing and storage costs. The following are the cost estimation explanations for different Kafka Providers:

- [AutoMQ](cost-explanation/automq.md)
- [Apache Kafka](cost-explanation/kafka.md)
- [Apache MSK](cost-explanation/msk.md)

### Dependent Action Secrets

- AUTOMQ_ACCESS_KEY: AWS Access Key
- AUTOMQ_SECRET_KEY: AWS Secret Key
- INFRA_COST_API_KEY: Infracost API Key. Can be obtained from [Infracost](https://www.infracost.io/)
- SSH_PRIVATE_KEY: SSH Private Key, directly fixed in secrets
- SSH_PUBLIC_KEY: SSH Public Key, directly fixed in secrets
- TF_BACKEND_BUCKET: S3 Bucket for storing Terraform State
- TF_BACKEND_KEY: S3 Key for storing Terraform State

## Comparison Report Generation Cycle

We plan to trigger the workflow to generate a comparison report every Monday at 8 AM.

## Roadmap

- Add horizontal automated comparisons for Kafka Providers such as Confluent/Aiven/Redpanda/WarpStream/Pulsar
- Support comparison of elasticity, i.e., how long it takes for the Client to recover from scaling actions
- Add tests related to Kafka compatibility.
- More visually appealing and readable comparative reports.

## License

Licensed under the Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0

The original works is from the [OpenMessaging Benchmark Framework](https://github.com/openmessaging/benchmark/).
