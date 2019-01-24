#!/usr/bin/env bash

set -eo pipefail


printf "Creating Harbor Project with the following:"
printf "  Harbor FQDN: $HARBOR_FQDN"
printf "  Harbor USERNAME: $HARBOR_USERNAME"
printf "  Harbor PASSWORD: ****"
printf "  Harbor PROJECT NAME: $PROJECT_NAME"
printf "  Harbor PROJECT PUBLIC: $PUBLIC"

curl -k -v \
 -u $HARBOR_USERNAME:$HARBOR_PASSWORD \
 -X POST "https://$HARBOR_FQDN/api/projects" \
 -H "accept: application/json" \
 -H "Content-Type: application/json" \
 -d "{ \"project_name\": \"$PROJECT_NAME\", \"metadata\": { \"public\": \"$PUBLIC\"}}"