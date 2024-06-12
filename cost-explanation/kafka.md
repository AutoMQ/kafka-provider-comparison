## Workload
This cost estimate is based on the following workload requirements:

- Write throughput: 500MB/s
- Production and consumption ratio: 1:1
- All Kafka Providers use a unified data retention time of 24 hours. Here, we assume that the storage system initially retains 24 hours of data. Given the write throughput, data retention for 24 hours, and the size of 1 copy of raw data is 24h * 3600s * 500MB/s, totaling 42187.5 GB.
- The total cost estimate is based on 1 month (720 hours).

## EC2

- Type: r6i.large, in/out is 100MB/s
- Number of brokers: 15. For 500MB/s input, this corresponds to 3 times the output (2 copies for replication, 1 for consumption), totaling 1500MB/s out, which requires 15 r6i.large instances.

Thus, the Kafka [var.tfvars](../driver-kafka/deploy/aws-cn/var.tfvars) configuration for the number of brokers/servers is as follows:
```
instance_type = {
  "server"              = "r6i.large"
  "broker"              = "r6i.large"
  "client"              = "r6i.large"
}

instance_cnt = {
  "server"              = 3
  "broker"              = 12
  "client"              = 5
}
```
> Tips: The client machines are fixed to 5 r6i.large instances, and this cost is automatically deducted in the Kafka Provider Comparison.

## SSD (per EC2)

Apache Kafka's SSD cost is independent of data size.

- System volume: 64GB
- Data volume: 25313 GB. For 1 day retention time, 3 copies, 500MB/s continuous write requires 3 * 24 * 3600 * 500 MB/s ≈ 126,562.5GB, distributed across 15 EC2 instances, each requiring 8437.5 GB.




- Due to Kafka's storage architecture design, the [var.tfvars](../driver-kafka/deploy/aws-cn/var.tfvars) configuration for data volume EBS is as follows. The IOPS and throughput meet AWS's free tier standards.
```
ebs_volume_type = "gp3"
ebs_volume_size = 8438
ebs_iops = 3000
ebs_throughput = 125
```

## Infracost usage configuration file
Kafka does not require S3, so we modified the default template `automq-medium-500m.yml` to [kafka-medium-500m.yml](../infracost/kafka-medium-500m.yml) and set all S3 usage to 0 to avoid s3 cost. The configuration file is as follows:
```yaml
    standard: # Usages of S3 Standard:
      storage_gb: 0 # Total storage in GB.
      monthly_tier_1_requests: 0 # Monthly PUT, COPY, POST, LIST requests (Tier 1).
      monthly_tier_2_requests: 0 # Monthly GET, SELECT, and all other requests (Tier 2).
      monthly_select_data_scanned_gb: 0 # Monthly data scanned by S3 Select in GB.
      monthly_select_data_returned_gb: 0 # Monthly data returned by S3 Select in GB.
```
