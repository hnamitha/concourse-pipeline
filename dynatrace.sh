#!/bin/bash

PARAMETER_ID="/common/TERRAFORM_DT_AUTOMATION_CLIENT_ID"
PARAMETER_SECRET="/common/TERRAFORM_DT_AUTOMATION_CLIENT_SECRET"

if [ -z "$1" ]; then
  echo "Provide environment name: 'dev', 'staging', 'production', etc."
  exit 1
else
  env=$1
fi

function setup_directory {
  local env="$1"
  mkdir -p "dashboards/${env}"
  cd "dashboards/${env}"
}

case "${env}" in
  dev)
    profile=674312962124:Admin
    url=https://mya27733.apps.dynatrace.com/platform/document/v1/documents
    setup_directory "${env}"
    ;;
  staging)
    profile=860907195624:Admin
    url=https://czw06748.apps.dynatrace.com/platform/document/v1/documents
    setup_directory "${env}"
    ;;
  nft)
    profile=214296788293:Admin
    url=https://pop61036.apps.dynatrace.com/platform/document/v1/documents
    setup_directory "${env}"
    ;;  
  regression)
    profile=187495793752:Admin
    url=https://row06733.apps.dynatrace.com/platform/document/v1/documents
    setup_directory "${env}"
    ;;  
  production)
    profile=446133167807:Admin
    url=https://vcz83894.apps.dynatrace.com/platform/document/v1/documents
    setup_directory "${env}"
    ;;
  *)
    echo "Environment: $1 not exist"
    echo "Please provide environment name: 'dev', 'staging', 'production', 'nft', 'regression'"
    exit 1
    ;;
esac

client_id=$(aws ssm get-parameter \
                --name "${PARAMETER_ID}" \
                --with-decryption --region  eu-west-1 \
                --profile ${profile}  \
                --query "Parameter.Value" --output text)

client_secret=$(aws ssm get-parameter \
                --name "${PARAMETER_SECRET}" --with-decryption  --region eu-west-1 \
                --profile ${profile} \
                --query "Parameter.Value" --output text)

if [ -z "${client_id}" ]; then
  echo "Failed to retrieve client id from Parameter Store"
  exit 1
fi

if [ -z "${client_secret}" ]; then
  echo "Failed to retrieve client secret from Parameter Store"
  exit 1
fi

dt_bearer=$(curl  -s -X POST 'https://sso.dynatrace.com/sso/oauth2/token' \
            --header 'Content-Type: application/x-www-form-urlencoded' \
            --data-urlencode 'grant_type=client_credentials' \
            --data-urlencode "client_id=${client_id}" \
            --data-urlencode "client_secret=${client_secret}" \
            --data-urlencode 'scope=document:documents:read'  | jq -r '.access_token') 


dashboard_id=$(curl -s -X GET "${url}" \
            -H 'accept: application/json' --header "Authorization: Bearer ${dt_bearer}" \
            |  jq -r '{dash: [.documents[] | select(.type == "dashboard") | {id: .id, name: .name}]}')

array=($(echo "${dashboard_id}" | jq -r '.dash[] | .id' ))

for id in "${array[@]}"
do
  content=$(curl  -s -X GET "${url}/${id}/content" \
            -H 'accept: application/json'  --header "Authorization: Bearer ${dt_bearer}")
  dashboard_name=$(echo "${dashboard_id}" | jq -r ".dash[] | select(.id == \"${id}\") | .name" | tr -d ' ')
  echo "${content}" > "${dashboard_name}.json" 
done

