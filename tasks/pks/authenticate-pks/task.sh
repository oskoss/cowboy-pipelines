#!/usr/bin/env bash

set -eo pipefail

mkdir -p ~/.pks/
mkdir -p ~/.kube/

pks login -a "$PKS_API_URL" -u "$PKS_API_USERNAME" -p "$PKS_API_PASSWORD" -k

cp ~/.pks/creds.yml pks-config/creds.yml