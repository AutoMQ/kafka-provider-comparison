## Kafka Provider Comparison

Kafka Provider Comparison (KPC) 是基于 OpenMessaging Benchmark 的代码构建的公开的 Kafka 对比平台。Kafka API
当前已经成为流领域的事实标准。近些年来，也出现了很多新的 Kafka API Compatible 的流系统（下文简称 Kafka Provider）。
构建该对比平台的初衷并不是希望决出谁是最好的 Kafka 流系统，而是提供一个**公平**、**客观**、**开放**的的对比环境生成客观、公平的 Kafka
流系统对比报告。对比报告会包含多个对比维度，包括延迟、成本、弹性、吞吐等等。不同产品的设计架构和trade-off不同，自然也会在不同的对比维度上有不同的表现。这份客观的对比结果对于用户做技术选型也将会是非常有帮助的。

## Supported Kafka Provider

* [AutoMQ](https://www.automq.com)
* [Apache Kafka](https://kafka.apache.org)

## 对比平台执行逻辑

对比平台的所有执行逻辑封装在 Github Actions 中，通过 Github Actions 的 Workflow 来触发对比任务的执行。对比任务的执行逻辑如下：

1. Github Actions 满足定时触发条件，触发 Workflow 执行。
2. Workflow 中包含的多个 Kafka Provider 的 Benchmark 流程会并行执行
3. 每个 Benchmark Provider 流程中包含如下几个顺序执行地子阶段，会依次执行。不同的 Kafka Provider 会同时进行评测。
    1. Install: 在 AWS 上根据 Terraform 配置文件初始化云资源、检出代码、安装依赖然后利用 ansible playbook 安装 Kafka
       Provider。该阶段也会根据 Terraform 的配置文件计算成本，作为后续最终 Comparison Report 的一部分。
    2. Benchmark: 依赖 Install 阶段并且在其完成后才会触发执行。该阶段主要是利用 Terraform Output 的信息远程登入到云上的 Client 机器，执行 OpenMessaging Benchmark 测试。
    3. Generate Report: 在 Github Runner 机器上会拷贝云端 Client 执行地 Benchmark 结果文件，解析其中内容生成最终 Report 内容，并且展示在 [issue-1](https://github.com/AutoMQ/kafka-provider-comparison/issues/1)
    4. Uninstall: 依赖 Benchmark 阶段并且在其完成后才会触发执行。该阶段会清理云资源，包括删除云上的 Client 机器、删除云上的 Kafka Provider 集群。


## Benchmark Report 说明
一份完整的 Benchmark Report 会包含如下内容：
- Report Generated: Report 的生成时间。根据该生成时间，你可以从开源仓库的 Github Actions 当中看到具体 Workflow 的执行细节，包括 cost 是如何计算的，Benchmark 的输出日志等。
- Workload Configuration: 从 OpenMessagging Benchmark 的运行日志中提取出来的 Workload 配置信息。为了保证对比的公平性，针对所有的 Kafka Provider 我们均会采用完全相同的 Workload、Producer、Consumer 配置。
- Producer Configuration: 生产者配置，所有 Kafka Provider 的 Producer 配置均相同。
- Consumer Configuration: 消费者配置，所有 Kafka Provider 的 Consumer 配置均相同。
- Topic Configuration: Topic 配置，所有 Kafka Provider 的 Topic 配置均相同。
- Replication Factor: 复制因子，所有 Kafka Provider 的复制因子均相同。
- Average Throughput: 整个 Benchmark 过程中的平均吞吐量，单位 MB/s
- E2E LatencyAvg(ms): 整个 Benchmark 过程中的平均端到端延迟，单位 ms
- E2E P95 Latency(ms): 整个 Benchmark 过程中的 95% 端到端延迟，单位 ms
- E2E P99 Latency(ms): 整个 Benchmark 过程中的 99% 端到端延迟，单位 ms
- Baseline Cost: 该 Kafka Provider 的基线成本(不包含用量的 IaaS 云服务成本)，单位 USD。基于 [Infracost](https://www.infracost.io/) 分析 Terraform 的配置文件询价得出。
- Usage Cost: 该 Kafka Provider 的云资源用量成本，单位 USD。基于 [Infracost](https://www.infracost.io/) 分析 Terraform 的配置文件和用量配置询价得出。用量是基于 `infracost` 目录下的 infracost usage 来进行计算的。例如，针对 AutoMQ 我们根据实际的生产经验得出每GB的写入流量对应 31.25 PUTs and 12.5 GETs。因此会根据固定的平均写入流量 10MB/s 计算出每秒的 API 调用数量来计算成本。关于这块成本估算逻辑，我们会在后续的章节中详细说明。
- Total Cost: 该 Kafka Provider 的总成本，单位 USD。其值等于基线成本加上用量成本。

## 如何贡献
假设你的 Kafka provider 名称为 `foo`，则你将新建如下内容来将 `foo` 纳入比较列表:
在跟目录下新建 `driver-foo` 模块，该模块 `/deploy/aws-cn` 目录下将包含如下关键文件:
   - provision-kafka-aws.tf: 定义了 Terraform 资源
   - var.tfvars: 可以自定义机型、磁盘大小、broker/server 数量等配置

> Tips: 当前仅支持在 aws-cn 进行对比，后续会支持更多云厂商。测试允许用户使用不同数量和规格的机器，但是要求满足最低的平均吞吐要求，否则结果将不予以展示。使用较高的机器规格会提高性能表现，但是也会导致成本的提升。

### 固化的 Workload
为了保证对比的公平性，我们固化了一套比较有代表性的 Workload，Producer、Consumer 配置 `tail-read-500m.yaml`。该配置支持产生理论峰值 500 MB/s 的写入流量。

#### Workload 配置
```
name: 1-topic-1000-partitions-4kb-4p4c-500m

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

#### Producer 配置
```
value.serializer: org.apache.kafka.common.serialization.ByteArraySerializer
acks: all
batch.size: 65536
bootstrap.servers: 10.0.0.120:9092,10.0.1.103:9092
key.serializer: org.apache.kafka.common.serialization.StringSerializer
linger.ms: 1
```

#### Consumer 配置
```
key.deserializer: org.apache.kafka.common.serialization.StringDeserializer
value.deserializer: org.apache.kafka.common.serialization.ByteArrayDeserializer
enable.auto.commit: true
bootstrap.servers: 10.0.0.82:9092
auto.offset.reset: earliest
```

### 成本估算
成本估算的难点在于云服务用量的估算。不同产品的实现存在差异，导致用量成本很难精确估算。但是，通过将存储的实现分成如下几种模式并且配合一个前提假设，我们即可相对公平的来计算用量成本。

当前 Kafka Provider 的存储实现依据依赖的云服务总体可以分为如下几种模式：
- 同时依赖云盘和对象存储: AutoMQ、Confluent Tiered Storage、Redpanda
- 只依赖对象存储: StreamNative USAR、WarpStream
- 只依赖云盘: Apache Kafka
关于云服务存储上的用量，我们只要假设 `在同一种存储模式上，假设大家都是相对优的实现，则写入流量与用量之间的关系是比较接近的`，这样我们针对一种存储模式，只要使用一种 infracost 用量模板即可。

用量的另外一个关键因子是副本数。同一份写入流量，副本数会直接影响实际需要的存储空间以及写入流量。像 AutoMQ 可以使用单副本保证高可用，相比 Apache Kafka 则会减少2份写入流量，存储成本上也会减少三分之二的存储空间。因此，计算成本时，根据 Kafka Provider 所需要的副本数，我们也会对用量成本进行相应的调整。例如 AutoMQ 需要 6T 的存储空间，而 Apache Kafka 就需要 18T 的存储空间。


### 依赖的 Action Secrets
- AUTOMQ_ACCESS_KEY: AWS Access Key
- AUTOMQ_SECRET_KEY: AWS Secret Key
- INFRA_COST_API_KEY: Infracost API Key. 可以从 [Infracost](https://www.infracost.io/) 获取
- SSH_PRIVATE_KEY: SSH Private Key，直接固化在 secrets 当中
- SSH_PUBLIC_KEY: SSH Public Key，直接固化在 secrets 当中
- TF_BACKEND_BUCKET: 存放 Terraform State 的 S3 Bucket
- TF_BACKEND_KEY: 存放 Terraform State 的 S3 Key

## 对比报告生成周期
我们计划每周生成一份对比报告。

### TODO
- 支持将 Kafka Provider 的 templates、ansible.cfg 等统一管理，避免新增 Kafka Provider 时需要重复编写这些文件。
- 当前支持的设备名采用固化的/dev/nvme1n1，可能不准。