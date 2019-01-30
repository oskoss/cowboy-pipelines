#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/

cp kube-config/config ~/.kube/config

cat << EOF > rbac-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF

kubectl apply -f rbac-config.yaml

if [ -z "$TILLER_IMAGE" ]
then
      printf "No Tiller Image Specified...using the default gcr.io/kubernetes-helm/tiller"
      export TILLER_IMAGE="gcr.io/kubernetes-helm/tiller:"
else
      printf "TILLER_IMAGE Specified as: $TILLER_IMAGE"
fi

if [ -z "$TILLER_IMAGE_TAG" ]
then
      printf "No Tiller Image Tag Specified...using the default v2.12.2"
      export TILLER_IMAGE="$TILLER_IMAGE:v2.12.2"
else
      printf "TILLER_IMAGE_TAG Specified as: $TILLER_IMAGE_TAG"
      export TILLER_IMAGE="$TILLER_IMAGE:$TILLER_IMAGE_TAG"
fi

helm init --service-account tiller \
--tiller-image $TILLER_IMAGE --skip-refresh

set +eo pipefail
printf "Checking to see if Tiller is ready:"
kubectl get pods --field-selector=status.phase==Running -n kube-system | grep tiller
while [ $? -ne 0 ]; do
  printf "Checking again...."
  sleep 10
  kubectl get pods --field-selector=status.phase==Running -n kube-system | grep tiller
done
printf "Success :)"