#!/usr/bin/env bash
# Deploy PKS on vsphere

set -eo pipefail


function generate_cert () (
  set -eu
  local domains="$1"

  local data=$(echo $domains | jq --raw-input -c '{"domains": (. | split(" "))}')

  local response=$(
    om-linux \
      --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
      --client-id "${OPSMAN_CLIENT_ID}" \
      --client-secret "${OPSMAN_CLIENT_SECRET}" \
      --username "$OPSMAN_USERNAME" \
      --password "$OPSMAN_PASSWORD" \
      --skip-ssl-validation \
      curl \
      --silent \
      --path "/api/v0/certificates/generate" \
      -x POST \
      -d $data
    )

  echo "$response"
)

# PKS API CERT
if [[ "${PKS_SSL_CERT1}" == "" || "${PKS_SSL_CERT1}" == "null" ]]; then
  domains=(
    "$PKS_API"    
  )

  certificate=$(generate_cert "${domains[*]}")
  pks_api_ssl_cert_value=`echo $certificate | jq '.certificate'`
  pks_api_ssl_key=`echo $certificate | jq '.key'`
  pks_api_ssl_cert="{
        \"cert_pem\": $pks_api_ssl_cert_value,
        \"private_key_pem\": $pks_api_ssl_key
    }"
else
  pks_api_ssl_cert="{
      \"cert_pem\": "${POE_SSL_CERT1}",
      \"private_key_pem\": "${POE_SSL_KEY1}"
  }"
fi

pks_properties=$(
  jq -n \
    --arg vcenter_host "$VCENTER_HOST" \
    --arg vcenter_username "$VCENTER_USR" \
    --arg vcenter_password "$VCENTER_PWD" \
    --arg datacenter "$VCENTER_DATA_CENTER" \
    --arg pks_api_hostname "$PKS_API" \
    --arg pks_vsphere_datastore "$PKS_VSPHERE_DATASTORE" \
    --arg bosh_vms_folder "$BOSH_VMS_FOLDER" \
    --arg availability_zones "$DEPLOYMENT_NW_AZS" \
    --arg pks_vrli_enabled "$PKS_VRLI_ENABLED" \
    --arg pks_vrli_fqdn "$PKS_VRLI_FQDN" \
    --argjson pks_api_ssl_cert "$pks_api_ssl_cert" \
    '
    {
       ".pivotal-container-service.pks_tls": {
            "value": $pks_api_ssl_cert
        }, 
        ".properties.cloud_provider": {
            "value": "vSphere"
        }, 
        ".properties.cloud_provider.vsphere.vcenter_ip": {
            "value": $vcenter_host
        }, 
        ".properties.cloud_provider.vsphere.vcenter_dc": {
            "value": $datacenter
        },     
        ".properties.cloud_provider.vsphere.vcenter_master_creds": {
            "value": {
                "password": $vcenter_password, 
                "identity": $vcenter_username
            }
        },
        ".properties.cloud_provider.vsphere.vcenter_vms": {
            "value": $bosh_vms_folder
        },
        ".properties.cloud_provider.vsphere.vcenter_ds": {
            "value": $pks_vsphere_datastore
        }, 
        ".properties.network_selector": {
            "value": "flannel"
        },
        ".properties.worker_max_in_flight": {
            "value": 1
        }, 
        ".properties.uaa_oidc": {
            "value": false
        }, 
        ".properties.sink_resources": {
            "value": true
        },   
        ".properties.pks_api_hostname": {
            "value": $pks_api_hostname
        },
        ".properties.telemetry_selector.enabled.interval": {
            "value": 600
        }
    }
    +
    if $pks_vrli_enabled == "true" then
    {
        ".properties.pks-vrli": {
            "value": "enabled"
        },
        ".properties.pks-vrli.enabled.host": {
            "value": $pks_vrli_fqdn
        },
        ".properties.pks-vrli.enabled.skip_cert_verify": {
            "value": true
        },
        ".properties.pks-vrli.enabled.use_ssl": {
            "value": false 
        },
    }
    else
    {
        ".properties.pks-vrli": {
            "value": "disabled"
        },
    }
    end
    +
    { 
        ".properties.proxy_selector": {
            "value": "Disabled"
        }, 
        ".properties.uaa.ldap.external_groups_whitelist": {
            "value": "*"
        }, 
        ".properties.uaa.ldap.ldap_referrals": {
            "value": "follow"
        }, 
        ".properties.telemetry_selector": {
            "value": "disabled"
        },
        ".properties.pks-vrli.enabled.skip_cert_verify": {
            "value": true
        },
        ".properties.wavefront": {
            "value": "disabled"
        }, 
        ".properties.plan2_selector.active.allow_privileged_containers": {
            "value": true
        }, 
        ".properties.plan2_selector.active.errand_vm_type": {
            "value": "micro"
        }, 
        ".properties.plan3_selector.active.errand_vm_type": {
            "value": "micro"
        },  
        ".properties.plan1_selector.active.master_instances": {
            "value": 1
        }, 
        ".properties.plan3_selector.active.disable_deny_escalating_exec": {
            "value": false
        }, 
        ".properties.plan1_selector.active.worker_az_placement": {
            "value": ($availability_zones | split(","))
        }, 
        ".properties.plan1_selector.active.master_az_placement": {
            "value": ($availability_zones | split(","))
        }, 
        ".properties.plan2_selector.active.master_az_placement": {
            "value": ($availability_zones | split(","))
        }, 
        ".properties.plan2_selector.active.worker_az_placement": {
            "value": ($availability_zones | split(","))
        },        
        ".properties.plan3_selector.active.master_az_placement": {
            "value": ($availability_zones | split(","))
        }, 
        ".properties.plan3_selector.active.worker_az_placement": {
            "value": ($availability_zones | split(","))
        }, 
        ".properties.plan1_selector.active.disable_deny_escalating_exec": {
            "value": true
        }, 
        ".properties.plan2_selector": {
            "value": "Plan Active"
        }, 
        ".properties.plan2_selector.active.worker_persistent_disk_type": {
            "value": "10240"
        }, 
        ".properties.plan3_selector.active.allow_privileged_containers": {
            "value": true
        }, 
        ".properties.plan2_selector.active.master_instances": {
            "value": 1
        }, 
        ".properties.plan1_selector.active.worker_persistent_disk_type": {
            "value": "10240"
        }, 
        ".properties.plan1_selector.active.description": {
            "value": "Developer K8s Cluster: This plan will configure a kubernetes cluster built for development"
        }, 
        ".properties.plan2_selector.active.master_vm_type": {
            "value": "medium"
        }, 
        ".properties.plan1_selector.active.name": {
            "value": "Dev-Cluster"
        }, 
        ".properties.plan1_selector.active.master_persistent_disk_type": {
            "value": "10240"
        }, 
        ".properties.plan3_selector.active.master_vm_type": {
            "value": "medium.disk"
        }, 
        ".properties.plan1_selector.active.worker_instances": {
            "value": 3
        }, 
        ".properties.plan3_selector.active.name": {
            "value": "Prod-Cluster"
        }, 
        ".properties.plan1_selector": {
            "value": "Plan Active"
        }, 
        ".properties.plan2_selector.active.description": {
            "value": "Test K8s Cluster: This plan will configure a kubernetes cluster built for testing"
        }, 
        ".properties.plan1_selector.active.errand_vm_type": {
            "value": "micro"
        }, 
        ".properties.plan3_selector.active.description": {
            "value": "Production K8s Cluster: This plan will configure a kubernetes cluster built for production"
        }, 
        ".properties.plan2_selector.active.worker_instances": {
            "value": 3
        }, 
        ".properties.plan3_selector": {
            "value": "Plan Active"
        },
        ".properties.plan2_selector.active.master_persistent_disk_type": {
            "value": "10240"
        }, 
        ".properties.plan3_selector.active.master_instances": {
            "value": 3
        }, 
        ".properties.plan3_selector.active.worker_instances": {
            "value": 5
        }, 
        ".properties.plan3_selector.active.master_persistent_disk_type": {
            "value": "10240"
        },  
        ".properties.plan2_selector.active.name": {
            "value": "Test-Cluster"
        }, 
        ".properties.uaa": {
            "value": "internal"
        }, 
        ".properties.plan1_selector.active.master_vm_type": {
            "value": "medium"
        }, 
        ".properties.plan3_selector.active.worker_persistent_disk_type": {
            "value": "51200"
        }, 
        ".properties.plan1_selector.active.worker_vm_type": {
            "value": "medium"
        }, 
        ".properties.plan1_selector.active.allow_privileged_containers": {
            "value": true
        }, 
        ".properties.plan2_selector.active.disable_deny_escalating_exec": {
            "value": true
        }, 
        ".properties.plan3_selector.active.worker_vm_type": {
            "value": "large.disk"
        }
    }
    '
)

pks_network=$(
  jq -n \
    --arg network_name "$NETWORK_NAME" \
    --arg service_network "$SERVICE_NETWORK_NAME" \
    --arg other_azs "$PKS_SINGLETON_JOB_AZ" \
    --arg singleton_az "$PKS_SINGLETON_JOB_AZ" \
    '
    {
      "network": {
        "name": $network_name
      },
      "other_availability_zones": ($other_azs | split(",") | map({name: .})),
      "singleton_availability_zone": {
        "name": $singleton_az
      },
      "service_network": {
        "name": $service_network
      }
    }
    '
)

JOB_RESOURCE_CONFIG="{
  \"pivotal-container-service\": { 
      \"instances\": \"automatic\",
      \"persistent_disk\": { \"size_mb\": \"automatic\" },
      \"instance_type\": { \"id\": \"automatic\" }
      }
}"

      
pks_resources=$(
  jq -n \
    --arg iaas "$IAAS" \
    --argjson job_resource_config "${JOB_RESOURCE_CONFIG}" \
    '
    $job_resource_config    
    '
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$OPSMAN_USERNAME" \
  --password "$OPSMAN_PASSWORD" \
  --skip-ssl-validation \
  configure-product \
  --product-name pivotal-container-service \
  --product-properties "$pks_properties" \
  --product-network "$pks_network" \
  --product-resources "$pks_resources"