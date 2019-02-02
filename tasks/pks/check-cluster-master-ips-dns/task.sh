#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/

cp pks-config/creds.yml ~/.pks/creds.yml 

cluster_fqdn=$(pks cluster $CLUSTER_NAME --json | jq -r '.parameters.kubernetes_master_host')
cluster_ips_string=$(pks cluster $CLUSTER_NAME --json | jq -r '.kubernetes_master_ips[]')
cluster_ips=($cluster_ips_string)

printf "\nChecking if PKS $CLUSTER_NAME Cluster Master IPs resolve with DNS Server: $DNS_SERVER_IP......"

set +eo pipefail

printf "\n\nPLEASE ENSURE $cluster_fqdn RESOLVES TO ONE OR ALL OF THE FOLLOWING PKS CLUSTER MASTER IPS:"

for elem in "${cluster_ips[@]}"
do 
printf "\n    $elem"
done

printf "\nCHECKING......"
host "$cluster_fqdn" "$DNS_SERVER_IP"
while [ $? -ne 0 ]; do
  printf "FAILED"
  sleep 10
  printf "\n\nPLEASE ENSURE $cluster_fqdn RESOLVES TO ONE OR ALL OF THE FOLLOWING PKS CLUSTER MASTER IPS:"

  for elem in "${cluster_ips[@]}"
  do 
    printf "\n    $elem"
  done
  host "$cluster_fqdn" "$DNS_SERVER_IP"
done

resolvedIp=$(host "$cluster_fqdn" "$DNS_SERVER_IP" | sed -n -e 's/^.*has address //p')
for ip in "${cluster_ips[@]}"
do
    if [ "$ip" == "$resolvedIp" ] ; then
        printf "Success :)"
        exit 0
    fi
done

printf "FAILED"
printf "\nDNS Server $DNS_SERVER_IP resolved $cluster_fqdn to $resolvedIp but this is not ${cluster_ips[@]} Bailing out...."
exit 1
