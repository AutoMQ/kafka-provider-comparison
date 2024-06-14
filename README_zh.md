[English](README.md) | [简体中文](README_zh.md)
![](images/kpc_banner.png)

## Kafka Provider Comparison

Kafka Provider Comparison (KPC) 是基于 OpenMessaging Benchmark 的代码构建的公开的 Kafka 对比平台。Kafka API
当前已经成为流领域的事实标准。近些年来，也出现了很多新的 Kafka API Compatible 的流系统（下文简称 Kafka Provider）。
构建该对比平台的初衷并不是希望决出谁是最好的 Kafka 流系统，而是提供一个**公平**、**客观**、**开放**的的对比环境生成客观、公平的 Kafka
流系统对比报告。对比报告会包含多个对比维度，包括延迟、成本、弹性、吞吐等等。不同产品的设计架构和trade-off不同，自然也会在不同的对比维度上有不同的表现。这份客观的对比结果对于用户做技术选型也将会是非常有帮助的。

## 支持的 Kafka Provider

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
- Pub Latency (ms) avg: 整个 Benchmark 过程中的平均发布延迟，单位 ms
- Pub Latency (ms) P99: 整个 Benchmark 过程中的 P99 发布延迟，单位 ms
- E2E LatencyAvg(ms): 整个 Benchmark 过程中的平均端到端延迟，单位 ms
- E2E P95 Latency(ms): 整个 Benchmark 过程中的 P95 端到端延迟，单位 ms
- E2E P99 Latency(ms): 整个 Benchmark 过程中的 P99 端到端延迟，单位 ms
- Baseline Cost: 该 Kafka Provider 的基线成本(不包含用量的 IaaS 云服务成本)，单位 USD。基于 [Infracost](https://www.infracost.io/) 分析 Terraform 的配置文件询价得出。
- Usage Cost: 该 Kafka Provider 的云资源用量成本，单位 USD。基于 [Infracost](https://www.infracost.io/) 分析 Terraform 的配置文件和用量配置询价得出。用量是基于 `infracost` 目录下的 infracost usage 来进行计算的。例如，针对 AutoMQ 我们根据实际的生产经验得出每GB的写入流量对应 31.25 PUTs and 12.5 GETs。因此会根据固定的平均写入流量 10MB/s 计算出每秒的 API 调用数量来计算成本。关于这块成本估算逻辑，我们会在后续的章节中详细说明。
- Total Cost: 该 Kafka Provider 的总成本，单位 USD。其值等于基线成本加上用量成本。

## 如何贡献
假设你的 Kafka provider 名称为 `foo`，则你将新建如下内容来将 `foo` 纳入比较列表:
在跟目录下新建 `driver-foo` 模块，该模块 `/deploy/aws-cn` 目录下必须包含如下关键文件:
   - var.tfvars: 默认情况下，为了保证workload以及生产、消费模式的固定，我们暂时只开放了如下值的自定义。如果这些配置不适合你的 Kafka Provider，你可以提交新的 PR 并且说明需要开放哪些新的值设置，以及原因。
   - deploy.yaml: ansible-playbook 的配置文件，用于部署具体的 Kafka Provider
   - cost_explanation.md: 用于解释成本是如何计算的文档。不同 Kafka Provider 的实现不方式不同，导致一些计算、存储服务的用量上会有明显差异。为了保证公平、公开性，请提供详细的成本用量计算逻辑说明。该部分说明可以参考工程目录下 `cost-explanation` 下已有的文件。
   - infracost usage config yaml: 在根目录的 infracost 下我们提供了默认的 `template-medium-500m` 模板文件，也是 infracost medium 规模默认的用量配置文件。你可以根据你的 Kafka Provider 的实际情况来修改这个文件，以便更准确的计算用量成本。并将这些修改项在 `cost-explanation/foo.md` 中进行公开说明。

完成上述步骤后你需要在 `.github/workflows` 下的三个文件中按照其他 Kafka Provider 的写法新增一个 Job 来保证 Workflow 定时执行时也可以执行你的 Kafka Provider 的 Benchmark 流程。如果你对如何贡献有任何疑问，欢迎在本项目下提交 issue 或者加入我们的 [Slack](https://join.slack.com/t/automq/shared_invite/zt-29h17vye9-thf31ebIVL9oXuRdACnOIA) 频道进行讨论。

您可以 Fork 我们的代码并且在你本地进行测试。当你测试满意后，您可以提交 PR 到我们的仓库。我们会在收到 PR 后进行 Review 并且合并。合并后我们会检查你的代码在我们 workflow 上执行地准确性，如果有问题我们会在 PR 上进行反馈，并且在 workflow 中暂时关闭你的 Kafka Provider 的执行和对比(针对新的 kafka provider) 或者 回退历史版本。

> Tips: 当前仅支持在 aws-cn 的 cn-northwest-1 进行对比，后续会支持更多云厂商和地域。测试允许用户使用不同数量和规格的机器。使用较高的机器规格会提高性能表现，但是也会导致成本的提升。

### 如何贡献没有开源的 Kafka Provider
KPC 也支持没有开源的 Kafka Provider 的对比。如果你的 Kafka Provider 没有开源，可以提供一个加密过或者经过代码混淆的基础镜像通过贡献新的 Kafka Provider 在我们的环境中进行部署和测试。针对那种当前没有开源也没有提供镜像的 Kafka Provider，例如 Confluent/Aiven 等，我们也会利用他们提供的 terraform provider 来进行部署。

### 固化的 Workload 配置
为了保证对比的公平性，我们固化了一套比较有代表性的 Workload，Producer、Consumer 配置 [tail-read-500m.yaml](workloads/vs/fast-tail-read-500m.yaml)。该配置支持产生理论峰值 500 MB/s 的写入流量。

### 成本估算
#### 成本估算的挑战与解法
对于固定规模的云服务的资源成本的开销是可以明确计算的。而成本估算的难点在于云服务用量的估算。云服务针对不同服务的用量会进行计量和收费。例如S3的API调用、存储空间等。不同产品的实现存在差异，导致用量成本的估算是一件非常有挑战的事情。为了保证估算的准确和公平性，我们会在每个 Kafka Provider 的 driver 目录下提供一个以 kafka provider name 命名的 markdown 文件，用于解释成本是如何计算的。不同 Kafka Provider 的实现方式不同，导致一些计算、存储服务的用量上会有明显差异。为了保证公平、公开性，我们会保证所有的 kafka provider 针对计算、存储的成本估算均供详细的成本计算逻辑说明。以下是不同 Kafka Provider 成本估算的说明:

- [AutoMQ](cost-explanation/automq.md)
- [Apache Kafka](cost-explanation/kafka.md)




### 依赖的 Action Secrets
- AUTOMQ_ACCESS_KEY: AWS Access Key
- AUTOMQ_SECRET_KEY: AWS Secret Key
- INFRA_COST_API_KEY: Infracost API Key. 可以从 [Infracost](https://www.infracost.io/) 获取
- SSH_PRIVATE_KEY: SSH Private Key，直接固化在 secrets 当中
- SSH_PUBLIC_KEY: SSH Public Key，直接固化在 secrets 当中
- TF_BACKEND_BUCKET: 存放 Terraform State 的 S3 Bucket
- TF_BACKEND_KEY: 存放 Terraform State 的 S3 Key

## 对比报告生成周期
我们计划在每周一上午8点触发 workflow 生成一份对比报告。

## Roadmap
- 新增 Confluent/Aiven/Redpanda/WarpStream 等 Kafka Provider 的横向自动化对比
- 支持弹性能力的比较项，即 Client 需要多久从 扩缩容行为中完成回复
- 新增Kafka兼容性相关测试
- 更加美观和可读的横向对比报告