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

import math
from enum import Enum

HOUR_PER_MONTH = 730


class EC2Type(Enum):
    r6i_large = "r6i.large"


class EBSType(Enum):
    gp3 = "gp3"


class S3Type(Enum):
    standard = "standard"


class CostInfo:
    class Unit(Enum):
        CNY = "CNY"
        USD = "USD"

    class S3:
        def __init__(self, storage: "dict[S3Type, float]", read: float, write: float):
            # S3 monthly cost per GB
            self.storage = storage
            # S3 read API (GET, SELECT) cost per request
            self.read = read
            # S3 write API (PUT, COPY, POST; LIST) cost per request
            self.write = write

    def __init__(
            self,
            unit: Unit,
            ec2_map: "dict[EC2Type, float]",
            ebs_map: "dict[EBSType, float]",
            s3: S3,
    ):
        self.unit = unit
        # EC2 hourly cost
        self.ec2_map = ec2_map
        # EBS monthly cost per GB
        self.ebs_map = ebs_map
        # S3 cost
        self.s3 = s3


def gigabit_to_bytes(g_bit: float) -> float:
    return g_bit * 1024 * 1024 * 1024 / 8


def megabyte_to_bytes(m_byte: float) -> float:
    return m_byte * 1024 * 1024


def bytes_to_gigabyte(bytes: float) -> float:
    return bytes / 1024 / 1024 / 1024


def hours_to_seconds(hours: float) -> float:
    return hours * 60 * 60


class AWSInfo:
    class Region(Enum):
        cn_northwest_1 = "cn-northwest-1"
        us_east_1 = "us-east-1"

    _COST_MAP: "dict[Region, CostInfo]" = {
        Region.cn_northwest_1: CostInfo(
            unit=CostInfo.Unit.CNY,
            ec2_map={
                EC2Type.r6i_large: 0.88313,
            },
            ebs_map={
                EBSType.gp3: 0.5312,
            },
            s3=CostInfo.S3(
                storage={
                    S3Type.standard: 0.1755,
                },
                read=0.00000135,
                write=0.00000405,
            ),
        ),
        Region.us_east_1: CostInfo(
            unit=CostInfo.Unit.USD,
            ec2_map={
                EC2Type.r6i_large: 0.133,
            },
            ebs_map={
                EBSType.gp3: 0.08,
            },
            s3=CostInfo.S3(
                storage={
                    S3Type.standard: 0.023,
                },
                read=0.0000004,
                write=0.000005,
            ),
        ),
    }

    # Network bandwidth baseline in Gbps
    _NETWORK_BANDWIDTH_MAP: "dict[EC2Type, float]" = {
        EC2Type.r6i_large: 0.781,
    }

    def __init__(self, region: Region) -> None:
        if region not in self._COST_MAP:
            raise Exception(f"Region {region} not supported")
        self.region = region

    def network_bandwidth_bytes(self, type: EC2Type) -> float:
        if type not in self._NETWORK_BANDWIDTH_MAP:
            raise Exception(f"Instance type {type} not supported")
        return gigabit_to_bytes(self._NETWORK_BANDWIDTH_MAP[type])

    def unit(self) -> CostInfo.Unit:
        return self._COST_MAP[self.region].unit.value

    def _ec2_cost_map(self):
        return self._COST_MAP[self.region].ec2_map

    def ec2_cost_hourly(self, type: EC2Type, count: int = 1) -> float:
        if type not in self._ec2_cost_map():
            raise Exception(f"Instance type {type} not supported")
        return self._ec2_cost_map()[type] * count

    def _ebs_cost_map(self):
        return self._COST_MAP[self.region].ebs_map

    def ebs_cost_hourly(self, type: EBSType, size_gb: int, count: int = 1) -> float:
        if type not in self._ebs_cost_map():
            raise Exception(f"EBS type {type} not supported")
        return self._ebs_cost_map()[type] * size_gb * count / HOUR_PER_MONTH

    def _s3_cost(self):
        return self._COST_MAP[self.region].s3

    def s3_storage_cost_hourly(self, type: S3Type, size_gb: int) -> float:
        if type not in self._s3_cost().storage:
            raise Exception(f"S3 type {type} not supported")
        return self._s3_cost().storage[type] / HOUR_PER_MONTH * size_gb

    def s3_read_cost(self, count: int) -> float:
        return self._s3_cost().read * count

    def s3_write_cost(self, count: int) -> float:
        return self._s3_cost().write * count


class KosCluster:
    def __init__(
            self,
            region: AWSInfo.Region = AWSInfo.Region.cn_northwest_1,
            instance_type: EC2Type = EC2Type.r6i_large,
            controller_count: int = 3,
            min_broker_count: int = 1,
            ebs_type: EBSType = EBSType.gp3,
            ebs_size_gb: int = 20,
            s3_type: S3Type = S3Type.standard,
            network_threshold: float = 0.8,
            spot_cutoff: float = 0.7,
    ) -> None:
        self.aws_info = AWSInfo(region)
        self.instance_type = instance_type
        self.controller_count = controller_count
        self.min_broker_count = min_broker_count
        self.ebs_type = ebs_type
        self.ebs_size_gb = ebs_size_gb
        self.s3_type = s3_type
        self.network_threshold = network_threshold
        self.spot_cutoff = spot_cutoff

    def info(self) -> str:
        return "         ** Kafka on S3 **\n" \
            f"           Region: {self.aws_info.region.value}\n" \
            f"    Instance type: {self.instance_type.value}\n" \
            f" Controller count: {self.controller_count}\n" \
            f" Min broker count: {self.min_broker_count}\n" \
            f"         EBS type: {self.ebs_type.value}\n" \
            f"         EBS size: {self.ebs_size_gb} GB\n" \
            f"          S3 type: {self.s3_type.value}\n" \
            f"Network threshold: {self.network_threshold}\n" \
            f"      Spot cutoff: {self.spot_cutoff}\n" \


    def broker_count(self, produce_throughput: float, subscription_count: int = 1) -> int:
        '''
        :param produce_throughput: Produce throughput in MB/s
        :param subscription_count: Subscription count per topic
        '''
        # upload to S3 + send to consumers
        out_throughput_bytes = megabyte_to_bytes(
            produce_throughput) * (1 + subscription_count)
        max_throughput_per_node_bytes = self.aws_info.network_bandwidth_bytes(
            self.instance_type) * self.network_threshold
        return max(self.controller_count + self.min_broker_count,
                   math.ceil(out_throughput_bytes / max_throughput_per_node_bytes)) - self.controller_count

    def instance_cost_hourly(self, produce_throughput: float, subscription_count: int = 1) -> (float, "dict[str, str]"):
        '''
        :param produce_throughput: Produce throughput in MB/s
        :param subscription_count: Subscription count per topic
        :return: (cost, detailed info)
        '''
        controller_cnt = self.controller_count
        broker_cnt = self.broker_count(produce_throughput, subscription_count)
        ec2_cost = self.aws_info.ec2_cost_hourly(
            self.instance_type, controller_cnt) + self.aws_info.ec2_cost_hourly(self.instance_type, broker_cnt) * (1 - self.spot_cutoff)
        ebs_cost = self.aws_info.ebs_cost_hourly(
            self.ebs_type, self.ebs_size_gb, controller_cnt + broker_cnt)
        detailed_info = {
            "Controller count": f"{controller_cnt:2d}",
            "Broker count": f"{broker_cnt:2d}",
            "EC2 cost": f"{ec2_cost:5.2f} {self.aws_info.unit()}",
            "EBS cost": f"{ebs_cost:4.2f} {self.aws_info.unit()}",
            "Total cost": f"{ec2_cost + ebs_cost:5.2f} {self.aws_info.unit()}",
        }
        return ec2_cost + ebs_cost, detailed_info

    def s3_cost_hourly(self, data_size: float) -> float:
        '''
        :param data_size: Data size in bytes
        '''
        return self.aws_info.s3_storage_cost_hourly(self.s3_type, bytes_to_gigabyte(data_size))


class KafkaCluster:
    def __init__(
            self,
            region: AWSInfo.Region = AWSInfo.Region.cn_northwest_1,
            instance_type: EC2Type = EC2Type.r6i_large,
            ebs_type: EBSType = EBSType.gp3,
            network_threshold: float = 0.8,
            ebs_threshold: float = 0.8,
            replication_factor: int = 3,
    ) -> None:
        self.aws_info = AWSInfo(region)
        self.instance_type = instance_type
        self.ebs_type = ebs_type
        self.network_threshold = network_threshold
        self.ebs_threshold = ebs_threshold
        self.replication_factor = replication_factor

    def info(self) -> str:
        return "         ** Apache Kafka **\n" \
            f"            Region: {self.aws_info.region.value}\n" \
            f"     Instance type: {self.instance_type.value}\n" \
            f"          EBS type: {self.ebs_type.value}\n" \
            f" Network threshold: {self.network_threshold}\n" \
            f"     EBS threshold: {self.ebs_threshold}\n" \
            f"Replication factor: {self.replication_factor}\n" \


    def node_count(self, max_throughput: float, subscription_count: int = 1) -> int:
        '''
        :param max_throughput: Max throughput in MB/s
        '''
        max_throughput_bytes = megabyte_to_bytes(max_throughput)
        max_throughput_per_node_bytes = self.aws_info.network_bandwidth_bytes(
            self.instance_type) * self.network_threshold / (self.replication_factor - 1 + subscription_count)
        return math.ceil(max_throughput_bytes / max_throughput_per_node_bytes)

    def ec2_cost_hourly(self, max_throughput: float, subscription_count: int = 1) -> float:
        '''
        :param max_throughput: Max throughput in MB/s
        '''
        return self.aws_info.ec2_cost_hourly(self.instance_type, self.node_count(max_throughput, subscription_count))

    def ebs_size(self, data_size: float) -> float:
        return data_size * self.replication_factor / self.ebs_threshold

    def ebs_cost_hourly(self, data_size_bytes: float) -> float:
        '''
        :param data_size: Data size in bytes
        '''
        data_size = bytes_to_gigabyte(data_size_bytes)
        return self.aws_info.ebs_cost_hourly(self.ebs_type, self.ebs_size(data_size))


if __name__ == "__main__":
    kos = KosCluster()
    kafka = KafkaCluster()
    print(kos.info())
    print(kafka.info())

    kos_instance_cost_total = 0
    data_size_bytes = 0
    throughput_list = [40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
                       800, 40, 40, 40, 40, 40, 1200, 40, 40, 40, 40, 40]
    for throughput in throughput_list:
        data_size_bytes += hours_to_seconds(1) * megabyte_to_bytes(throughput)

        kos_cost, detailed_info = kos.instance_cost_hourly(throughput)
        detailed_info = {
            "Throughput": f"{throughput:4d} MB/s", **detailed_info}
        # print("KoS: ", detailed_info)
        kos_instance_cost_total += kos_cost

    kos_s3_cost = kos.s3_cost_hourly(data_size_bytes) * len(throughput_list)
    kafka_ec2_cost_total = kafka.ec2_cost_hourly(
        max(throughput_list)) * len(throughput_list)
    kafka_ebs_cost = kafka.ebs_cost_hourly(
        data_size_bytes) * len(throughput_list)

    print(f"KoS instance cost: {kos_instance_cost_total:5.2f} {kos.aws_info.unit()}",
          f"KoS S3 cost: {kos_s3_cost:5.2f} {kos.aws_info.unit()}",
          f"KoS total cost: {kos_instance_cost_total + kos_s3_cost:5.2f} {kos.aws_info.unit()}",
          "",
          f"Kafka EC2 cost: {kafka_ec2_cost_total:5.2f} {kafka.aws_info.unit()}",
          f"Kafka EBS cost: {kafka_ebs_cost:5.2f} {kafka.aws_info.unit()}",
          f"Kafka total cost: {kafka_ec2_cost_total + kafka_ebs_cost:5.2f} {kafka.aws_info.unit()}",
          "",
          f"Kafka/Kos cost ratio: {(kafka_ec2_cost_total + kafka_ebs_cost) / (kos_instance_cost_total + kos_s3_cost):5.2f}",
          sep="\n")
