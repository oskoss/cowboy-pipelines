#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/
cp kube-config/config ~/.kube/config


cat << EOF > default-vsphere-storage-class.yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: vsphere-thin-disk
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/vsphere-volume
parameters:
    diskformat: thin
EOF

kubectl apply -f default-vsphere-storage-class.yaml
    