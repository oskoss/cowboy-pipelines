#!/bin/bash

STATE='/data/pivotal-state'

printf "\n" >>$STATE
printf "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n" >>$STATE
printf "++++++++++++ Pivotal Bootstrap Config script ++++++++++++\n" >>$STATE
printf "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n" >>$STATE

printf "\n" >>$STATE
date >>$STATE
printf "\npivotal-bootstrap-$VERSION running....\n" >>$STATE

# create XML file with settings
date +"%m.%d.%Y %T " ; printf "Fetching values"
vmtoolsd --cmd "info-get guestinfo.ovfenv" > /tmp/ovf_env.xml
TMPXML='/tmp/ovf_env.xml'

# gathering network values        
IP=`cat $TMPXML| grep -w ip |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
NETMASK=`cat $TMPXML| grep -w netmask |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
GW=`cat $TMPXML| grep -w gateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
DNS=`cat $TMPXML| grep -w dns |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

# Update network
printf "\n IP: $IP \n Netmask: $NETMASK \n Gateway: $GW \n DNS: $DNS \n" >>$STATE

cat << EOF > /etc/network/interfaces
# The loopback network interface  
auto lo  
iface lo inet loopback  

# The primary network interface
iface eth0 inet static
address $IP
netmask $NETMASK
gateway $GW
dns-nameservers $DNS

EOF

ifdown eth0 ; ifup eth0 & >>$STATE

# Cleanup Old Docker Containers
printf "\nCleaning Up Old Docker Containers\n" >>$STATE

docker kill $(docker ps -q) >>$STATE 2>&1
docker rm $(docker ps -a -q) >>$STATE 2>&1

# Setup Minio
printf "\nSetting Up Minio\n" >>$STATE

mkdir -p /data/minio
docker run -d \
    -p 9000:9000 \
    --restart=always \
    -e "MINIO_ACCESS_KEY=vcap" \
    -e "MINIO_SECRET_KEY=c1oudc0w" \
    -v /data/minio:/data \
    minio/minio:RELEASE.2019-01-16T21-44-08Z server /data >>$STATE 2>&1 &

# Setup Docker Registry
printf "\nSetting Up Docker\n" >>$STATE

mkdir -p /data/docker-registry
docker run -d \
    -p 5000:5000 \
    --restart=always \
    --name registry \
    -v /data/docker-registry:/var/lib/registry \
    registry:2.7.1 >>$STATE 2>&1 &

# Setup Postgres 
printf "\nSetting Up Postgres\n" >>$STATE

mkdir -p /data/postgres
docker run -d \
    -p 5432:5432 \
    --restart=always \
    --name=postgres \
    -v /data/postgres:/data \
    -e PGDATA=/data \
    -e POSTGRES_USER=vcap \
    -e POSTGRES_PASSWORD=c1oudc0w \
    postgres:11.1 >>$STATE 2>&1 &

sleep 10

printf "\nCreating gogs DB if not already exists\n" >>$STATE

docker run \
-e "PGPASSWORD=c1oudc0w" \
postgres:11.1 \
sh -c "psql -h $IP --username=vcap postgres -c 'CREATE DATABASE gogs'"  >>$STATE

printf "\nCreating atc DB for concourse if not already exists\n" >>$STATE

docker run \
-e "PGPASSWORD=c1oudc0w" \
postgres:11.1 \
sh -c "psql -h $IP --username=vcap postgres -c 'CREATE DATABASE atc'" >>$STATE

# Setup Gogs Git
printf "\nSetting Up Gogs Git\n" >>$STATE

rm -rf /data/git/gogs-repositories
mkdir -p /data/gogs/gogs/conf
mkdir -p /data/git/gogs-repositories

cat << EOF > /data/gogs/gogs/conf/app.ini
APP_NAME = Pivotal-Bootstrap
RUN_USER = git
RUN_MODE = prod

[database]
DB_TYPE  = postgres
HOST     = $IP:5432
NAME     = gogs
USER     = vcap
PASSWD   = c1oudc0w
SSL_MODE = disable
PATH     = data/gogs.db

[repository]
ROOT = /data/git/gogs-repositories

[server]
DOMAIN           = localhost
HTTP_PORT        = 3000
ROOT_URL         = http://localhost:3000/
DISABLE_SSH      = false
SSH_PORT         = 22
START_SSH_SERVER = false
OFFLINE_MODE     = false

[mailer]
ENABLED = false

[service]
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL     = false
DISABLE_REGISTRATION   = false
ENABLE_CAPTCHA         = true
REQUIRE_SIGNIN_VIEW    = false

[picture]
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = false

[session]
PROVIDER = file

[log]
MODE      = file
LEVEL     = Info
ROOT_PATH = /data/gogs/log

[security]
INSTALL_LOCK = true
SECRET_KEY   = HrC5t3OxbrbnBhJ
EOF

docker run -d \
    --name=gogs \
    -p 10022:22 \
    -p 3000:3000 \
    -v /data/gogs:/data \
    gogs/gogs:0.11.79 & >>$STATE

printf  "\nAdding admin user to Gogs Git\n" >>$STATE
printf  "\nSleeping...... to let Gogs start up\n" >>$STATE

sleep 30
docker exec gogs sh -c "su -c \"/app/gogs/gogs admin create-user --name=vcap --password=c1oudc0w --email=no-reply@pivotal.io --admin=true\" git" & >>$STATE

# Setup Concourse
printf "\nSetting Up Concourse" >>$STATE

mkdir -p /data/concourse >>$STATE
chmod 777 /data/concourse >>$STATE

/usr/bin/concourse quickstart \
  --add-local-user vcap:c1oudc0w \
  --main-team-local-user vcap \
  --external-url http://$IP:8080 \
  --worker-work-dir /data/concourse \
  --postgres-password="c1oudc0w" \
  --postgres-user="vcap" \
  --worker-baggageclaim-log-level=debug \
  --worker-log-level=debug \
  --worker-garden-log-level=debug \
  --tsa-log-level=debug \
  --log-level=debug >/data/pipelines/concourse.log 2>&1 &

printf "\n   Sleeping...... to let Concourse start up\n" >>$STATE

sleep 30

# gathering pipeline values        
VCENTER_USR=`cat $TMPXML| grep -w vcenter_usr |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
VCENTER_PWD=`cat $TMPXML| grep -w vcenter_pwd |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
VCENTER_DATACENTER=`cat $TMPXML| grep -w vcenter_datacenter |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
VCENTER_DATASTORE=`cat $TMPXML| grep -w vcenter_datastore |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_RESOURCE_POOL=`cat $TMPXML| grep -w om_resource_pool |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
VCENTER_HOST=`cat $TMPXML| grep -w vcenter_host |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_IP=`cat $TMPXML| grep -w om_ip |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_SSH_PASSWORD=`cat $TMPXML| grep -w om_ssh_password |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_NTP_SERVERS=`cat $TMPXML| grep -w om_ntp_servers |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_DNS_SERVERS=`cat $TMPXML| grep -w om_dns_servers |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_GATEWAY=`cat $TMPXML| grep -w om_gateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_NETMASK=`cat $TMPXML| grep -w om_netmask |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
OM_VM_NETWORK=`cat $TMPXML| grep -w om_vm_network |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
EPHEMERAL_DATASTORE=`cat $TMPXML| grep -w ephemeral_datastore |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
PERSISTENT_DATASTORE=`cat $TMPXML| grep -w persistent_datastore |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
MANAGEMENT_VSPHERE_NETWORK=`cat $TMPXML| grep -w management_vsphere_network |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
MANAGEMENT_NW_CIDR=`cat $TMPXML| grep -w management_nw_cidr |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
MANAGEMENT_EXCLUDED_RANGE=`cat $TMPXML| grep -w management_excluded_range |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
MANAGEMENT_NW_DNS=`cat $TMPXML| grep -w management_nw_dns |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
MANAGEMENT_NW_GATEWAY=`cat $TMPXML| grep -w management_nw_gateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
WORKLOAD_VSPHERE_NETWORK=`cat $TMPXML| grep -w workload_vsphere_network |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
WORKLOAD_NW_CIDR=`cat $TMPXML| grep -w workload_nw_cidr |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
WORKLOAD_EXCLUDED_RANGE=`cat $TMPXML| grep -w workload_excluded_range |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
WORKLOAD_NW_DNS=`cat $TMPXML| grep -w workload_nw_dns |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
WORKLOAD_NW_GATEWAY=`cat $TMPXML| grep -w workload_nw_gateway |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
AZ_1_CLUSTER_NAME=`cat $TMPXML| grep -w az_1_cluster_name |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
AZ_1_RP_NAME=`cat $TMPXML| grep -w az_1_rp_name |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
AZ_2_CLUSTER_NAME=`cat $TMPXML| grep -w az_2_cluster_name |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
AZ_2_RP_NAME=`cat $TMPXML| grep -w az_2_rp_name |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
AZ_3_CLUSTER_NAME=`cat $TMPXML| grep -w az_3_cluster_name |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
AZ_3_RP_NAME=`cat $TMPXML| grep -w az_3_rp_name |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
NTP_SERVERS=`cat $TMPXML| grep -w ntp_servers |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
PKS_API_FQDN=`cat $TMPXML| grep -w pks_api_fqdn |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
VRLI_FQDN=`cat $TMPXML| grep -w vrli_fqdn |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
PKS_VRLI_ENABLED=`cat $TMPXML| grep -w pks_vrli_enabled |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'|tr '[:upper:]' '[:lower:]'`
HARBOR_FQDN=`cat $TMPXML| grep -w harbor_fqdn |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
CONTROL_CLUSTER_FQDN=`cat $TMPXML| grep -w control_cluster_fqdn |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`

cat << EOF > /data/pipelines/cowboy-pipelines/pipelines/edge-deploy-params.yaml
vcenter_usr: "$VCENTER_USR"
vcenter_pwd: "$VCENTER_PWD"
vcenter_datacenter: "$VCENTER_DATACENTER"
vcenter_datastore: "$VCENTER_DATASTORE"
om_resource_pool: "$OM_RESOURCE_POOL"
vcenter_host: "$VCENTER_HOST"
opsman_domain_or_ip_address: "$OM_IP"
om_ssh_password: "$OM_SSH_PASSWORD"
om_ntp_servers: "$NTP_SERVERS"
om_dns_servers: "$OM_DNS_SERVERS"
om_gateway: "$OM_GATEWAY"
om_netmask: "$OM_NETMASK"
om_ip: "$OM_IP"
om_vm_network: "$OM_VM_NETWORK"
om_vm_name: "PivotalOperationsManager"
om_vm_folder:
disk_type: "thick"
ephemeral_datastore: "$EPHEMERAL_DATASTORE"
persistent_datastore: "$PERSISTENT_DATASTORE"
bosh_vm_folder: "pivotal_bosh_vms"
bosh_template_folder: "pivotal_bosh_templates"
bosh_disk_path: "pivotal_bosh_disks"
icmp_checks_enabled: "false"
management_network_name: "management"
management_vsphere_network: "$MANAGEMENT_VSPHERE_NETWORK"
management_nw_cidr: "$MANAGEMENT_NW_CIDR"
management_excluded_range: "$MANAGEMENT_EXCLUDED_RANGE"
management_nw_dns: "$MANAGEMENT_NW_DNS"
management_nw_gateway: "$MANAGEMENT_NW_GATEWAY"
management_nw_azs: "az1"
workload_network_name: "workload"
workload_vsphere_network: "$WORKLOAD_VSPHERE_NETWORK"
workload_nw_cidr: "$WORKLOAD_NW_CIDR"
workload_excluded_range: "$WORKLOAD_EXCLUDED_RANGE"
workload_nw_dns: "$WORKLOAD_NW_DNS"
workload_nw_gateway: "$WORKLOAD_NW_GATEWAY"
workload_nw_azs: "az1,az2,az3"
az_1_name: "az1"
az_1_cluster_name: "$AZ_1_CLUSTER_NAME"
az_1_rp_name: "$AZ_1_RP_NAME"
az_2_name: "az2"
az_2_cluster_name: "$AZ_2_CLUSTER_NAME"
az_2_rp_name: "$AZ_2_RP_NAME"
az_3_name: "az3"
az_3_cluster_name: "$AZ_3_CLUSTER_NAME"
az_3_rp_name: "$AZ_3_RP_NAME"
ntp_servers: "$NTP_SERVERS"
enable_vm_resurrector: "true"
enable_post_deploy: "true"
platform_username: "vcap"
platform_password: "c1oudc0w"
max_threads: 30
nsx_networking_enabled: "false"
pks_api_fqdn: "$PKS_API_FQDN"
nsx_networking_enabled: "false"
iaas: "vsphere"
pks_vrli_fqdn: "$VRLI_FQDN"
pks_vrli_enabled: "$PKS_VRLI_ENABLED"
harbor_auth_mode: "db_auth"
harbor_ssl_cert1: 
harbor_ssl_key1: 
harbor_api: "$HARBOR_FQDN"
harbor_use_clair: "true"
harbor_use_notary: "true"
harbor_registry_storage: "filesystem"
harbor_ldap_auth_url: 
harbor_ldap_auth_verify_cert: 
harbor_ldap_auth_searchdn: 
harbor_ldap_auth_searchpwd: 
harbor_ldap_auth_basedn: 
harbor_ldap_auth_uid: 
harbor_ldap_auth_filter: 
harbor_ldap_auth_scope: 
harbor_ldap_auth_timeout: 
harbor_s3_registry_storage_access_key: 
harbor_s3_registry_storage_secret_key: 
harbor_s3_registry_storage_region: 
harbor_s3_registry_storage_endpoint_url: 
harbor_s3_registry_storage_bucket: 
harbor_s3_registry_storage_root_directory: 
harbor_server_cert_ca_pem: 
harbor_use_ca_cert: "false"
nsx_address:
nsx_ca_certificate:
nsx_password:
nsx_username:
ops_dir_hostname:
trusted_certificates: 
pks_ssl_cert1:
pks_ssl_key1:
opsman_client_secret:
opsman_client_id:

minio_s3_endpoint: http://$IP:9000
ci_tasks_git_endpoint: http://$IP:3000/vcap/cowboy-pipelines.git
control-k8s-cluster-FQDN: "$CONTROL_CLUSTER_FQDN"
control-k8s-cluster-pks-plan: "Prod-Cluster"
charts_git_endpoint: http://$IP:3000/vcap/charts.git

harbor_insecure_reg: $HARBOR_FQDN
bootstrap_insecure_reg: http://$IP:5000

bootstrap_ci_image: $IP:5000/oskoss/cowboy-pipelines
bootstrap_concourse_image: $IP:5000/concourse/concourse
bootstrap_postgres_image: $IP:5000/postgres
bootstrap_traefik_image: $IP:5000/traefik
bootstrap_tiller_image: $IP:5000/kubernetes-helm/tiller
bootstrap_ubuntu_image: $IP:5000/ubuntu
bootstrap_java_image: $IP:5000/openjdk
bootstrap_bitnami_kafka_image: $IP:5000/bitnami/kafka
bootstrap_bitnami_zookeeper_image: $IP:5000/bitnami/zookeeper
bootstrap_bitnami_cassandra_image: $IP:5000/bitnami/cassandra

harbor_ci_image: $HARBOR_FQDN/oskoss/cowboy-pipelines
harbor_concourse_image: $HARBOR_FQDN/concourse/concourse
harbor_postgres_image: $HARBOR_FQDN/postgres/postgres
harbor_traefik_image: $HARBOR_FQDN/traefik/traefik
harbor_tiller_image: $HARBOR_FQDN/kubernetes-helm/tiller
harbor_ubuntu_image: $HARBOR_FQDN/ubuntu/ubuntu
harbor_java_image: $HARBOR_FQDN/openjdk/openjdk
harbor_bitnami_kafka_image: $HARBOR_FQDN/bitnami/kafka
harbor_bitnami_zookeeper_image: $HARBOR_FQDN/bitnami/zookeeper
harbor_bitnami_cassandra_image: $HARBOR_FQDN/bitnami/cassandra

postgres_image_tag: 9.6.2
traefik_image_tag: 1.7.7
ci_image_tag: 0.1
concourse_image_tag: 4.2.2
tiller_image_tag: v2.12.0
ubuntu_image_tag: xenial
java_image_tag: 8-jdk
bitnami_kafka_image_tag: 2.1.0
bitnami_zookeeper_image_tag: 3.4.13
bitnami_cassandra_image_tag: 3.11.3

traefik_helm_repo: http://$HARBOR_FQDN/chartrepo/traefik
concourse_helm_repo: http://$HARBOR_FQDN/chartrepo/concourse
traefik_chart_values: "dashboard.enabled=true,serviceType=NodePort,image=$HARBOR_FQDN/traefik/traefik,imageTag=1.7.7,accessLogs.enabled=true,dashboard.domain=traefik.$CONTROL_CLUSTER_FQDN,rbac.enabled=true"
concourse_chart_values: "image=$HARBOR_FQDN/concourse/concourse,web.ingress.enabled=true,web.ingress.hosts[0]=concourse.$CONTROL_CLUSTER_FQDN,postgresql.image=$HARBOR_FQDN/postgres/postgres,postgresql.imageTag=9.6.2"
EOF

printf "\n   Set Pipeline Parameters:\n" >>$STATE
cat /data/pipelines/cowboy-pipelines/pipelines/edge-deploy-params.yaml >>$STATE

printf "\n   Setting Up Pipeline $PIPELINE\n" >>$STATE
iptables -P FORWARD ACCEPT

export HOME=/root
fly -t local login --concourse-url http://127.0.0.1:8080 -u vcap -p c1oudc0w >>$STATE 2>&1

# Determine if Pipeline should be reset
RESET_PIPELINE=`cat $TMPXML| grep -w reset_pipeline |sed -n -e '/value\=/ s/.*\=\" *//p'|sed 's/\"\/>//'`
printf "\n   Reset Pipeline Status: $RESET_PIPELINE\n" >>$STATE

if [ "$RESET_PIPELINE" = "True" ]; then
    printf "\n   Setting New Pipeline" >>$STATE
    fly -t local set-pipeline -n -p initial-deploy -c /data/pipelines/cowboy-pipelines/pipelines/edge-deploy-pipeline.yml --load-vars-from=/data/pipelines/cowboy-pipelines/pipelines/edge-deploy-params.yaml >>$STATE 2>&1
    fly -t local unpause-pipeline -p initial-deploy >>$STATE 2>&1
    fly -t local trigger-job -j initial-deploy/deploy-pivotal-ops-manager-ova >>$STATE 2>&1
fi

# Determine if Pipeline has NEVER been set
fly -t local pipelines --json | grep initial-deploy
retVal=$?

if [ $retVal -ne 0 ]; then
    printf "\n   Pipeline has never been set" >>$STATE
    printf "\n   Setting Pipeline" >>$STATE
    fly -t local set-pipeline -n -p initial-deploy -c /data/pipelines/cowboy-pipelines/pipelines/edge-deploy-pipeline.yml --load-vars-from=/data/pipelines/cowboy-pipelines/pipelines/edge-deploy-params.yaml >>$STATE 2>&1
    fly -t local unpause-pipeline -p initial-deploy >>$STATE 2>&1
    fly -t local trigger-job -j initial-deploy/deploy-pivotal-ops-manager-ova >>$STATE 2>&1
fi

# Fix bug where concourse keeps stale containers....
kill $(ps aux | grep concourse | grep runc | awk '{print $2}')

# Update status
printf "\n<<<<<<<<<<<<<<<<<<<Finished>>>>>>>>>>>>>>>>>>>>>> :)" >>$STATE
