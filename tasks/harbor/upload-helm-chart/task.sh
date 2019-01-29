#!/usr/bin/env bash

set -eo pipefail

cd chart-tar

printf "Uploading Helm Chart:"
printf "  Harbor FQDN: $HARBOR_FQDN"
printf "  Harbor USERNAME: $HARBOR_USERNAME"
printf "  Harbor PASSWORD: ****"
printf "  Harbor PROJECT NAME: $PROJECT_NAME"
printf "  Harbor CHART TAR: $TAR_FILENAME"

curl -k -v \
 -u $HARBOR_USERNAME:$HARBOR_PASSWORD \
 -X POST "https://$HARBOR_FQDN/api/chartrepo/$PROJECT_NAME/charts" \
 -H "accept: application/json" \
 -H "Content-Type: multipart/form-data" \
 -F "chart=@$TAR_FILENAME;type=application/x-tar"