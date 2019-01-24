#!/usr/bin/env bash

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

# HARBOR API CERT
if [[ "${HARBOR_SSL_CERT1}" == "" || "${HARBOR_SSL_CERT1}" == "null" ]]; then
  domains=(
    "$HARBOR_API"    
  )

  certificate=$(generate_cert "${domains[*]}")
  harbor_api_ssl_cert_value=`echo $certificate | jq '.certificate'`
  harbor_api_ssl_key=`echo $certificate | jq '.key'`
  harbor_api_ssl_cert="{
        \"cert_pem\": $harbor_api_ssl_cert_value,
        \"private_key_pem\": $harbor_api_ssl_key
    }"
else
  harbor_api_ssl_cert="{
      \"cert_pem\": "${HARBOR_SSL_CERT1}",
      \"private_key_pem\": "${HARBOR_SSL_KEY1}"
  }"
fi

harbor_properties=$(jq -n \
  --arg auth_mode "$AUTH_MODE" \
  --arg harbor_hostname "$HARBOR_API" \
  --arg harbor_admin_password "$HARBOR_ADMIN_PASSWORD" \
  --arg harbor_use_clair "$HARBOR_USE_CLAIR" \
  --arg harbor_use_notary "$HARBOR_USE_NOTARY" \
  --arg registry_storage "$HARBOR_REGISTRY_STORAGE" \
  --arg ldap_auth_url "$HARBOR_LDAP_AUTH_URL" \
  --arg ldap_auth_verify_cert "$HARBOR_LDAP_AUTH_VERIFY_CERT" \
  --arg ldap_auth_searchdn "$HARBOR_LDAP_AUTH_SEARCHDN" \
  --arg ldap_auth_searchpwd "$HARBOR_LDAP_AUTH_SEARCHPWD" \
  --arg ldap_auth_basedn "$HARBOR_LDAP_AUTH_BASEDN" \
  --arg ldap_auth_uid "$HARBOR_LDAP_AUTH_UID" \
  --arg ldap_auth_filter "$HARBOR_LDAP_AUTH_FILTER" \
  --arg ldap_auth_scope "$HARBOR_LDAP_AUTH_SCOPE" \
  --arg ldap_auth_timeout "$HARBOR_LDAP_AUTH_TIMEOUT" \
  --arg s3_registry_storage_access_key "$HARBOR_S3_REGISTRY_STORAGE_ACCESS_KEY" \
  --arg s3_registry_storage_secret_key "$HARBOR_S3_REGISTRY_STORAGE_SECRET_KEY" \
  --arg s3_registry_storage_region "$HARBOR_S3_REGISTRY_STORAGE_REGION" \
  --arg s3_registry_storage_endpoint_url "$HARBOR_S3_REGISTRY_STORAGE_ENDPOINT_URL" \
  --arg s3_registry_storage_bucket "$HARBOR_S3_REGISTRY_STORAGE_BUCKET" \
  --arg s3_registry_storage_root_directory "$HARBOR_S3_REGISTRY_STORAGE_ROOT_DIRECTORY" \
  --arg server_cert_ca_pem "$HARBOR_SERVER_CERT_CA_PEM" \
  --arg use_ca_cert "$USE_CA_CERT" \
  --argjson harbor_api_ssl_cert "$harbor_api_ssl_cert" \
  '{
    ".properties.hostname": {
      "value": $harbor_hostname
    },
    ".properties.admin_password": {
      "value": {
        "secret": $harbor_admin_password
     }
    },
    ".properties.with_clair": {
      "value": $harbor_use_clair
    },
    ".properties.with_notary": {
      "value": $harbor_use_notary
    },
    ".properties.registry_storage": {
      "value": $registry_storage
    },
    ".properties.auth_mode": {
      "value": $auth_mode
    },
    ".properties.server_cert_key": {
      "value": $harbor_api_ssl_cert
    }
  }
  +
  if $use_ca_cert == "true" then
  {
    ".properties.server_cert_ca": {
      "value": $server_cert_ca_pem
    }
  }
  else .
  end
  +
  if $auth_mode == "ldap_auth" then
  {
    ".properties.auth_mode.ldap_auth.url": {
      "value": $ldap_auth_url
    },
    ".properties.auth_mode.ldap_auth.verify_cert": {
      "value": $ldap_auth_verify_cert
    },
    ".properties.auth_mode.ldap_auth.searchdn": {
      "value": $ldap_auth_searchdn
    },
    ".properties.auth_mode.ldap_auth.searchpwd": {
      "value": {
        "secret": $ldap_auth_searchpwd
      }
    },
    ".properties.auth_mode.ldap_auth.basedn": {
      "value": $ldap_auth_basedn
    },
    ".properties.auth_mode.ldap_auth.uid": {
      "value": $ldap_auth_uid
    },
    ".properties.auth_mode.ldap_auth.filter": {
      "value": $ldap_auth_filter
    },
    ".properties.auth_mode.ldap_auth.scope": {
      "value": $ldap_auth_scope
    },
    ".properties.auth_mode.ldap_auth.timeout": {
      "value": $ldap_auth_timeout
    }
  }
  else .
  end
  +

  if $registry_storage == "s3" then
  {
    ".properties.registry_storage.s3.access_key": {
      "value": $s3_registry_storage_access_key
    },
    ".properties.registry_storage.s3.secret_key": {
      "value": {
        "secret": $s3_registry_storage_secret_key
      }
    },
    ".properties.registry_storage.s3.region": {
      "value": $s3_registry_storage_region
    },
    ".properties.registry_storage.s3.endpoint_url": {
      "value": $s3_registry_storage_endpoint_url
    },
    ".properties.registry_storage.s3.bucket": {
      "value": $s3_registry_storage_bucket
    },
    ".properties.registry_storage.s3.root_directory": {
      "value": $s3_registry_storage_root_directory
    }
  }
  else .
  end

  '
  )


harbor_network=$(jq -n \
  --arg network_name "$NETWORK_NAME" \
  --arg other_azs "$OTHER_AZS" \
  --arg singleton_az "$SINGLETON_JOBS_AZ" \
'
  {
    "network": {
      "name": $network_name
    },
    "other_availability_zones": ($other_azs | split(",") | map({name: .})),
    "singleton_availability_zone": {
      "name": $singleton_az
    }
  }
'
)

  om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$OPSMAN_USERNAME" \
  --password "$OPSMAN_PASSWORD" \
  --skip-ssl-validation \
  configure-product \
  --product-name harbor-container-registry \
  --product-properties "$harbor_properties" \
  --product-network "$harbor_network"