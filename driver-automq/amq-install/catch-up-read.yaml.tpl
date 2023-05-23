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

kos:
  installID: xxxxxxxxxxxxxxxx
  vpcID: vpc-xxxxxxxxxxxxxxxxx
  cidr: 10.0.1.0/24
  region: us-west-2
  zoneNameList: us-west-2a
  kafka:
    controllerCount: 1
    brokerCount: 20
    enablePublic: false
    heapOpts: "-Xms6g -Xmx6g -XX:MetaspaceSize=96m -XX:MaxDirectMemorySize=6g"
    commonSettings:
      - log.index.interval.bytes=10485760
      - metric.reporters=kafka.autobalancer.metricsreporter.AutoBalancerMetricsReporter,org.apache.kafka.server.metrics.s3stream.KafkaS3MetricsLoggerReporter
      - s3.metrics.logger.interval.ms=5000
      - autobalancer.controller.enable=false
      - s3.network.baseline.bandwidth=419430400
      - s3.block.cache.size=1073741824
      - s3.wal.capacity=3221225472
      - s3.wal.cache.size=2147483648
      - s3.wal.upload.threshold=536870912
      - s3.stream.object.split.size=8388608
      - s3.object.part.size=33554432
      - s3.stream.allocator.policy=POOLED_DIRECT
  scaling:
    enabled: false
    brokerOnDemandPercentage: 100
    maxBrokerSize: 20
  ec2:
    instanceType: r6in.large
    controllerSpotEnabled: false
    keyPairName: kafka_on_s3_benchmark_key-xxxxxxxxxxxxxxxx
    enablePublic: true
    enableDetailedMonitor: true
    deleteEbsOnTermination: true
    amiID: ami-05c9d64f683dcf6df
  accessKey: xxxxxxxxxxxxxxxxxxxx
  secretKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
