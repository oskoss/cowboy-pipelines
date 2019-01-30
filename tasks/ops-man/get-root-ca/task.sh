#!/usr/bin/env bash

set -eo pipefail

printf "Getting Root CA from $OPSMAN_DOMAIN_OR_IP_ADDRESS"

cert=`om -t https://opsman2.pcf.cloud.oskoss.com -k  --client-id "${OPSMAN_CLIENT_ID}"   --client-secret ""   -u "admin"   -p "Luxola50\!" certificate-authorities -f json | jq -r ".[0].cert_pem"` 



echo $cert > ca-cert/root_ca.cert

