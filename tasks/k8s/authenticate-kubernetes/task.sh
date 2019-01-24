#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/

cp pks-config/creds.yml ~/.pks/creds.yml 

pks get-credentials "$PKS_CLUSTER_NAME"

kubectl cluster-info

cp ~/.kube/config kube-config/config

chmod 644 kube-config/config