[server]
%{ for i, instance in server ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address } index=${ i } kafka_id=${ server_kafka_ids[i] } data_volume=/dev/vdb data_volume_iops=2800
%{ endfor ~}

[broker]
%{ for i, instance in broker ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address } index=${ i } kafka_id=${ broker_kafka_ids[i] } data_volume=/dev/vdb data_volume_iops=2800
%{ endfor ~}

[client]
%{ for i, instance in client ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address } index=${ i }
%{ endfor ~}

[telemetry]
%{ for i, instance in telemetry ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address }
%{ endfor ~}

[all:vars]
cloud_provider=aliyun
s3_endpoint=https://${ oss_endpoint }
s3_region=${ oss_region }
s3_bucket=${ oss_bucket }
cluster_id=${ cluster_id }
access_key=${ access_key }
secret_key=${ secret_key }
role_name=${ role_name }
