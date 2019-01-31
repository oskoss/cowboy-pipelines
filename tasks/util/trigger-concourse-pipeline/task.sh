#!/usr/bin/env bash

set -eo pipefail

export https_proxy=internet.proxy.fedex.com:3128
export http_proxy=internet.proxy.fedex.com:3128

wget https://github.com/concourse/concourse/releases/download/v4.2.2/fly_linux_amd64 -O fly

export HOME=/root
printf "Logging into Concourse $CONCOURSE_URL"
./fly -t local login --concourse-url $CONCOURSE_URL -u $CONCOURSE_USERNAME -p $CONCOURSE_PASSWORD
printf "Unpausing Pipeline $CONCOURSE_PIPELINE"
./fly -t local unpause-pipeline -p $CONCOURSE_PIPELINE
printf "Triggering Pipeline $CONCOURSE_PIPELINE and Job $CONCOURSE_JOB"
./fly -t local trigger-job -j $CONCOURSE_PIPELINE/$CONCOURSE_JOB --watch
