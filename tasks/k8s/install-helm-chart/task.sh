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



if [ -z "$HELM_REPO_URL" ]
then
  printf "No Helm Repo specified, defaulting to stable -- internet access required"
  helm_repo_name="stable"
  helm init --client-only
else
  printf "Helm Repo specified as $HELM_REPO_URL adding repo"
  helm_repo_name="ciHelmRepo"
  helm init --client-only --skip-refresh
  helm repo add $helm_repo_name $HELM_REPO_URL
fi

printf "Chart Values: \n $CHART_VALUES"

if [ -z "$CHART_VALUES" ]
then
  HELM_OPTIONS=""
else
  HELM_OPTIONS="--set $CHART_VALUES"
fi

# Install the Chart
helm upgrade $RELEASE_NAME $helm_repo_name/$CHART_NAME --namespace $NAMESPACE --install $HELM_OPTIONS --debug