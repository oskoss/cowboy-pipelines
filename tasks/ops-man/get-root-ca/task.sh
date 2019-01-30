#!/usr/bin/env bash

set -eo pipefail

printf "Getting Root CA from $OPSMAN_DOMAIN_OR_IP_ADDRESS"

cert=`om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --format json \
  certificate-authorities | jq ".[0].cert_pem"`

echo -ne $cert > ca-cert/temp_root_ca.cert
sed -e "s/\"//" ca-cert/temp_root_ca.cert  > ca-cert/root_ca.cert
rm -f ca-cert/temp_root_ca.cert