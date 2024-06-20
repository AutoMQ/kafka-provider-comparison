## Workload

This cost estimate is based on the following workload requirements:

- Write throughput: 500MB/s
- Production and consumption ratio: 1:1
- All Kafka Providers use a unified data retention time of 24 hours. Here, we assume that the storage system initially retains 24 hours of data. Given the write throughput, data retention for 24 hours, and the size of 1 copy of raw data is 24h * 3600s * 500MB/s, totaling 42187.5 GB.
- The total cost estimate is based on 1 month (720 hours).

## MSK Configuration

### Broker Type

Amazon MSK is essentially a managed Apache Kafka service, so the Broker Type corresponds closely to the EC2 instance types used by Apache Kafka. Since MSK does not offer instance types with a CPU to memory ratio similar to r6i.large, we initially tried selecting a Broker Type with a smaller specification but the same number (15) as used in our Apache Kafka tests, specifically kafka.m5.large (2c8g), to see if it could meet the 500MB/s write requirement. However, based on our [actual test results](https://github.com/AutoMQ/kafka-provider-comparison/issues/1#issuecomment-2180020514), we found that although the throughput could reach 500MB/s in this scenario, the E2E P99 latency reached 757.91ms, which is significantly higher than our expectations. Therefore, to ensure reasonable results under the same workload, we used 15 kafka.m5.xlarge (4c16g) brokers in our formal comparison tests.

### Storage
For Amazon MSK, we specifically chose version 3.7.x.kraft, which supports tiered storage. However, according to the [Amazon MSK official configuration documentation](https://docs.amazonaws.cn/en_us/msk/latest/developerguide/msk-default-configuration.html), the retention time for local storage must be greater than 3 days. The tiered storage feature is effective only if your data retention time on local storage is greater than 3 days. In our current unified test scenario, data retention is calculated based on 24 hours, so the tiered storage advantage of Amazon MSK is not reflected in the current comparison. This means that if your data needs to be retained for more than three days and the volume is very large, tiered storage will bring additional cost benefits.

In our current test scenario (which is also a typical scenario for small to medium-scale streaming system applications), even when using MSK, the data is still entirely stored on local disks. For 1 day retention time, 3 copies, 500MB/s continuous write requires 3 * 24 * 3600 * 500 MB/s ≈ 126,562.5GB, distributed across 15 EC2 instances, each requiring 8437.5 GB.

### Final MSK Configuration
Thus, the Amazon MSK [provision-kafka-aws.tf](../driver-msk/deploy/aws-cn/provision-kafka-aws.tf) configuration for the comparison is as follows:

```
  cluster_name           = "mskcluster"
  kafka_version          = "3.7.x.kraft"
  number_of_broker_nodes = 15

  broker_node_group_info {
    instance_type  = "kafka.m5.xlarge"
    client_subnets = [
      aws_subnet.subnet_az1.id,
      aws_subnet.subnet_az2.id,
      aws_subnet.subnet_az3.id,
    ]
    storage_info {
      ebs_storage_info {
        #  Local retention time must greater than 3days. Ref: https://docs.amazonaws.cn/en_us/msk/latest/developerguide/msk-default-configuration.html
        volume_size = 8438
      }
    }
    security_groups = [aws_security_group.sg.id]
  }
```

> Tips: The client machines are fixed to 5 r6i.large instances, and this cost is automatically deducted in the Kafka Provider Comparison.



## Infracost usage configuration file
Amazon MSK 是 AWS 标准的云服务，主要包含了计算实例的固定费用和存储的用量费用。我们通过 Infracost 统一询价可以得到具体的费用开销。
