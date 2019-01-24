#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/

cp kube-config/config ~/.kube/config

if [ -z "$NAMESPACE" ]
then
  NAMESPACE="$RELEASE_NAME"
fi

printf "Creating K8s Namespace $NAMESPACE for new helm chart"

currentContext=$(kubectl config current-context)
kubectl create namespace $RELEASE_NAME || true
kubectl config set-context $currentContext --namespace=$NAMESPACE
kubectl config use-context $currentContext

helm init --client-only
cd charts/stable

printf "Chart Values: \n $CHART_VALUES"

if [ -z "$CHART_VALUES" ]
then
  HELM_OPTIONS=""
else
  HELM_OPTIONS="--set $CHART_VALUES"
fi

# Install the Chart
helm upgrade $RELEASE_NAME stable/$CHART_NAME --namespace $NAMESPACE --install $HELM_OPTIONS --debug
