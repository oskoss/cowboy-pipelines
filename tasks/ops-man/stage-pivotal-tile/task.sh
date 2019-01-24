#!/usr/bin/env bash

set -eo pipefail

AVAILABLE=$(om-linux \
  --skip-ssl-validation \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  curl -path /api/v0/available_products)
STAGED=$(om-linux \
  --skip-ssl-validation \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  curl -path /api/v0/staged/products)

# Should the slug contain more than one product, pick only the first.
FILE_PATH=`find ./pivotal-product -name *.pivotal | sort | head -1`
unzip $FILE_PATH metadata/*

PRODUCT_NAME="$(cat metadata/*.yml | grep '^name' | cut -d' ' -f 2)"
desired_version="$(cat metadata/*.yml | grep '^product_version' | cut -d' ' -f 2)"

# Figure out which products are unstaged.
UNSTAGED_ALL=$(jq -n --argjson available "$AVAILABLE" --argjson staged "$STAGED" \
  '$available - ($staged | map({"name": .type, "product_version": .product_version}))')

UNSTAGED_PRODUCT=$(echo "$UNSTAGED_ALL" | jq \
  --arg product_name "$PRODUCT_NAME" \
  --arg product_version "$desired_version" \
  'map(select(.name == $product_name)) | map(select(.product_version | startswith($product_version)))'
)

# There should be only one such unstaged product.
if [ "$(echo $UNSTAGED_PRODUCT | jq '. | length')" -ne "1" ]; then
  echo "Need exactly one unstaged build for $PRODUCT_NAME version $desired_version...CAUTION YOU ALREADY HAVE STAGED THIS......"
  jq -n "$UNSTAGED_PRODUCT"
  exit 0
fi

full_version=$(echo "$UNSTAGED_PRODUCT" | jq -r '.[].product_version')

om-linux --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
  --skip-ssl-validation \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  --username "${OPS_MGR_USR}" \
  --password "${OPS_MGR_PWD}" \
  stage-product \
  --product-name "${PRODUCT_NAME}" \
  --product-version "${full_version}"
