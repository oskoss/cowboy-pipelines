#!/usr/bin/env bash

set -eo pipefail


if [ -z "$DNS_IP" ]; then
  printf "No IP specified from ENV: \$DNS_IP"
  ls product-ip/ip
  if [ $? -ne 0 ]; then
    printf "No IP specified from product-ip input or ENV: \$DNS_IP"
    export MESSAGE="\n PLEASE ENSURE DNS SERVER: $DNS_SERVER_IP IS CONFIGURED CORRECTLY TO RESOLVE $DNS_HOSTNAME. \n SLEEPING AND TRYING AGAIN...."
  else
    read -r ipEntry < product-ip/ip && true
    if [ "$ipEntry" = "" ]; then
      printf "ip file was found inside product-ip input but there was nothing inside....bailing out!"
      exit 1
    fi
    printf "DNS_IP:  Specified from product-ip input"
    export DNS_IP="$ipEntry"
    export MESSAGE="\n PLEASE ENSURE DNS SERVER: $DNS_SERVER_IP IS CONFIGURED CORRECTLY TO RESOLVE $DNS_HOSTNAME TO $DNS_IP. \n SLEEPING AND TRYING AGAIN...."
  fi
else
  printf "ENV: \$DNS_IP found -- $DNS_IP \n FYI: ENV \$DNS_IP takes precendence over product-ip input"
  export MESSAGE="\n PLEASE ENSURE DNS SERVER: $DNS_SERVER_IP IS CONFIGURED CORRECTLY TO RESOLVE $DNS_HOSTNAME TO $DNS_IP. \n SLEEPING AND TRYING AGAIN...."
fi

set +eo pipefail

printf "\nChecking if hostname: $DNS_HOSTNAME resolves with DNS Server: $DNS_SERVER_IP......"
host "$DNS_HOSTNAME" "$DNS_SERVER_IP"
while [ $? -ne 0 ]; do
  printf "\nFAILED: Unable to resolve $DNS_HOSTNAME with DNS Server: $DNS_SERVER_IP"
  printf "$MESSAGE"
  sleep 10
  host "$DNS_HOSTNAME" "$DNS_SERVER_IP"
done

if [ -z $DNS_IP ]; then
  printf "Success :)"
  exit 0
else
  resolvedIp=$(host "$DNS_HOSTNAME" "$DNS_SERVER_IP" | sed -n -e 's/^.*has address //p')
  if [ "$resolvedIp" -eq "$DNS_IP" ]; then 
    printf "Success :)"
    exit 0
  else
    printf "DNS Server $DNS_SERVER_IP resolved $DNS_HOSTNAME to $resolvedIp but this is not $DNS_IP Bailing out...."
    exit 1
  fi
fi


