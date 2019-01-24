#!/usr/bin/env bash

set -eo pipefail

product_guid=$(om-linux -t https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  -u "$OPS_MGR_USR" \
  -p "$OPS_MGR_PWD" \
  -k \
  --request-timeout 3600 \
  curl --path /api/v0/deployed/products | \
  jq -r ".[] | select(.type == \"$OPSMAN_PRODUCT_NAME\") | .guid")

ip=$(om-linux -t https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  -u "$OPS_MGR_USR" \
  -p "$OPS_MGR_PWD" \
  -k \
  --request-timeout 3600 \
  curl --path "/api/v0/deployed/products/$product_guid/status" | \
  jq -r ".status[0].ips[0]")

printf "$OPSMAN_PRODUCT_NAME found with IP $ip"
printf "$ip" > product-ip/ip