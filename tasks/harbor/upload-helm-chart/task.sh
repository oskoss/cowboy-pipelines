#!/usr/bin/env bash

set -eo pipefail

cd chart-tar

num_of_files=$(ls -1A | wc -l)

if [ "$num_of_files" -eq "1" ]; then
  export chart_tar=`ls -1A | sort -n | head -1`
else
  printf "One helm chart tar required, you either have too many or not enough....bailing out"
  exit 1
fi

printf "Uploading Helm Chart:"
printf "  Harbor FQDN: $HARBOR_FQDN"
printf "  Harbor USERNAME: $HARBOR_USERNAME"
printf "  Harbor PASSWORD: ****"
printf "  Harbor PROJECT NAME: $PROJECT_NAME"
printf "  Harbor CHART TAR: $chart_tar"

curl -k -v \
 -u $HARBOR_USERNAME:$HARBOR_PASSWORD \
 -X POST "https://$HARBOR_FQDN/api/chartrepo/$PROJECT_NAME/charts" \
 -H "accept: application/json" \
 -H "Content-Type: multipart/form-data" \
 -F "chart=@$chart_tar;type=application/x-tar"