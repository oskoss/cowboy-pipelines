#!/usr/bin/env bash

set -eo pipefail

read -r ipEntry < product-ip/ip && true

if [ "$ipEntry" = "" ]; then
  echo "Found no IP....bailing out"
  exit 1
fi

printf "Creating $DNS_HOSTNAME with $ipEntry IP on DNS Server $DNS_SERVER_IP"

nsupdate -d <<EOF
server $DNS_SERVER_IP
update add $DNS_HOSTNAME 3600 A $ipEntry
send
EOF

printf "Checking if record was created successfully......"
host "$DNS_HOSTNAME" "$DNS_SERVER_IP"