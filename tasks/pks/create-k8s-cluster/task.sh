#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/

cp pks-config/creds.yml ~/.pks/creds.yml 

set +x

echo "Creating New PKS Cluster $CLUSTER_NAME with FQDN: $CLUSTER_FQDN"

set -x

pks create-cluster "$CLUSTER_NAME" \
--external-hostname  "$CLUSTER_FQDN" \
--plan "$CLUSTER_PLAN"
 
# wait until cluster is finished creating

set +x

while [ 1 ]
do
    status=`pks cluster "$CLUSTER_NAME" --json | jq -r '.last_action_state'`

    echo "Status of create-cluster is $status"
    if [ "$status" = "succeeded" ]
    then
        echo "Created $CLUSTER_NAME successfully"
        exit 0
    fi
    if [ "$status" = "failed" ]
    then
        echo "Failed..."
        exit 1
    fi
    sleep 30
done
