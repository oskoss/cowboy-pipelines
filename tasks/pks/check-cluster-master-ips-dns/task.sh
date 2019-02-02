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

resolved_ips=($(host "$cluster_fqdn" "$DNS_SERVER_IP" | sed -n -e 's/^.*has address //p'))
for cluster_ip in "${cluster_ips[@]}"
do
    for resolved_ip in "${resolved_ips[@]}"
    do
      if [ "$cluster_ip" == "$resolved_ip" ] ; then
          printf "Success :)"
          exit 0
      fi
    done
done

printf "FAILED"
printf "\nDNS Server $DNS_SERVER_IP resolved $cluster_fqdn to "
printf '%s,' "${resolved_ips[@]}"
printf " but this is not one of "
printf '%s,' "${cluster_ips[@]}"
printf " defined from \"pks cluster $CLUSTER_NAME\" Bailing out...."
exit 1
