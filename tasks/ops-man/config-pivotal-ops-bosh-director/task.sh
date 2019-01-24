#!/usr/bin/env bash

set -eo pipefail

echo "Configuring IaaS, AZ and Director..."
ops_man_root_ca=$(om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --format json \
  certificate-authorities | jq -r ".[0].cert_pem")

iaas_configuration=$(
  jq -n \
  --arg vcenter_host "$VCENTER_HOST" \
  --arg vcenter_username "$VCENTER_USR" \
  --arg vcenter_password "$VCENTER_PWD" \
  --arg datacenter "$VCENTER_DATA_CENTER" \
  --arg disk_type "$VCENTER_DISK_TYPE" \
  --arg ephemeral_datastores_string "$EPHEMERAL_STORAGE_NAMES" \
  --arg persistent_datastores_string "$PERSISTENT_STORAGE_NAMES" \
  --arg bosh_vm_folder "$BOSH_VM_FOLDER" \
  --arg bosh_template_folder "$BOSH_TEMPLATE_FOLDER" \
  --arg bosh_disk_path "$BOSH_DISK_PATH" \
  --argjson ssl_verification_enabled false \
  --argjson nsx_networking_enabled "$NSX_NETWORKING_ENABLED" \
  --arg nsx_address "$NSX_ADDRESS" \
  --arg nsx_username "$NSX_USERNAME" \
  --arg nsx_password "$NSX_PASSWORD" \
  --arg nsx_ca_certificate "$NSX_CA_CERTIFICATE" \
  '
  {
    "vcenter_host": $vcenter_host,
    "vcenter_username": $vcenter_username,
    "vcenter_password": $vcenter_password,
    "datacenter": $datacenter,
    "disk_type": $disk_type,
    "ephemeral_datastores_string": $ephemeral_datastores_string,
    "persistent_datastores_string": $persistent_datastores_string,
    "bosh_vm_folder": $bosh_vm_folder,
    "bosh_template_folder": $bosh_template_folder,
    "bosh_disk_path": $bosh_disk_path,
    "ssl_verification_enabled": $ssl_verification_enabled,
    "nsx_networking_enabled": $nsx_networking_enabled,
  }

  +

  # NSX networking. If not enabled, the following section is not required
  if $nsx_networking_enabled then
    {
      "nsx_address": $nsx_address,
      "nsx_username": $nsx_username,
      "nsx_password": $nsx_password,
      "nsx_ca_certificate": $nsx_ca_certificate
    }
  else
    .
  end
  '
)

az_configuration=$(cat <<-EOF
 [
    {
      "name": "$AZ_1",
      "cluster": "$AZ_1_CLUSTER_NAME",
      "resource_pool": "$AZ_1_RP_NAME"
    },
    {
      "name": "$AZ_2",
      "cluster": "$AZ_2_CLUSTER_NAME",
      "resource_pool": "$AZ_2_RP_NAME"
    },
    {
      "name": "$AZ_3",
      "cluster": "$AZ_3_CLUSTER_NAME",
      "resource_pool": "$AZ_3_RP_NAME"
    }
 ]
EOF
)

network_configuration=$(
  jq -n \
    --argjson icmp_checks_enabled $ICMP_CHECKS_ENABLED \
    --arg management_network_name "$MANAGEMENT_NETWORK_NAME" \
    --arg management_vcenter_network "$MANAGEMENT_VCENTER_NETWORK" \
    --arg management_network_cidr "$MANAGEMENT_NW_CIDR" \
    --arg management_reserved_ip_ranges "$MANAGEMENT_EXCLUDED_RANGE" \
    --arg management_dns "$MANAGEMENT_NW_DNS" \
    --arg management_gateway "$MANAGEMENT_NW_GATEWAY" \
    --arg management_availability_zones "$MANAGEMENT_NW_AZS" \
    --arg workload_network_name "$WORKLOAD_NETWORK_NAME" \
    --arg workload_vcenter_network "$WORKLOAD_VCENTER_NETWORK" \
    --arg workload_network_cidr "$WORKLOAD_NW_CIDR" \
    --arg workload_reserved_ip_ranges "$WORKLOAD_EXCLUDED_RANGE" \
    --arg workload_dns "$WORKLOAD_NW_DNS" \
    --arg workload_gateway "$WORKLOAD_NW_GATEWAY" \
    --arg workload_availability_zones "$WORKLOAD_NW_AZS" \
    '
    {
      "icmp_checks_enabled": $icmp_checks_enabled,
      "networks": [
        {
          "name": $management_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $management_vcenter_network,
              "cidr": $management_network_cidr,
              "reserved_ip_ranges": $management_reserved_ip_ranges,
              "dns": $management_dns,
              "gateway": $management_gateway,
              "availability_zone_names": ($management_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $workload_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $workload_vcenter_network,
              "cidr": $workload_network_cidr,
              "reserved_ip_ranges": $workload_reserved_ip_ranges,
              "dns": $workload_dns,
              "gateway": $workload_gateway,
              "availability_zone_names": ($workload_availability_zones | split(","))
            }
          ]
        }
      ]
    }'
)

director_config=$(cat <<-EOF
{
  "ntp_servers_string": "$NTP_SERVERS",
  "resurrector_enabled": $ENABLE_VM_RESURRECTOR,
  "post_deploy_enabled": $ENABLE_POST_DEPLOY,
  "max_threads": $MAX_THREADS,
  "database_type": "internal",
  "blobstore_type": "local",
  "director_hostname": "$OPS_DIR_HOSTNAME"
}
EOF
)

security_configuration=$(
  jq -n \
    --arg trusted_certificates "$ops_man_root_ca" \
    '
    {
      "trusted_certificates": $trusted_certificates,
      "vm_password_type": "generate"
    }'
)

network_assignment=$(
jq -n \
  --arg management_availability_zones "$MANAGEMENT_NW_AZS" \
  --arg network "$MANAGEMENT_NETWORK_NAME" \
  '
  {
  "singleton_availability_zone": {
    "name": ($management_availability_zones | split(",") | .[0])
  },
  "network": {
    "name": $network
  }
  }'
)

echo "Configuring IaaS, AZ and Director..."
om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  configure-director \
  --iaas-configuration "$iaas_configuration" \
  --director-configuration "$director_config" \
  --az-configuration "$az_configuration"

echo "Configuring Network and Security..."
om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  configure-director \
  --networks-configuration "$network_configuration" \
  --network-assignment "$network_assignment" \
  --security-configuration "$security_configuration"