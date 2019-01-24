#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/
cp pks-config/creds.yml ~/.pks/creds.yml 

set +x

master_ips=(`pks cluster $CLUSTER_NAME --json | jq -r '.kubernetes_master_ips | join(" ")'`)


printf "Creating $CLUSTER_FQDN with $master_ips IP on DNS Server $DNS_SERVER_IP"

echo "server $DNS_SERVER_IP" > updateFile

for elem in "${master_ips[@]}"
do 
  echo "update add $CLUSTER_FQDN 3600 A $elem" >> updateFile
done

echo "send" >> updateFile
nsupdate -d updateFile

printf "Checking if record was created successfully......"
host "$CLUSTER_FQDN" "$DNS_SERVER_IP"