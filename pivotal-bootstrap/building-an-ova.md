
# Grab BOSH Stemcell From BOSH.io

1/25/2019 Ubuntu Xenial 170.24

# Extract BOSH Stemcell To Import into vSphere

tar -xvf bosh-stemcell-170.23-vsphere-esxi-ubuntu-xenial-go_agent.tgz
tar -xvf image

# Import image.ovf into vSphere

All done in vcenter GUI
Add network card to VM
Expand 1st disk on VM to 10GB
Add 2nd disk to VM (120GB)
Ensure CD/DVD is set to client

# Boot VM Up and manually assign network 

Perform the following from the vCenter Client VM Console
FYI this is only temporary as the bootstrap systemd service automatically sets this after we build the ova.
Edit `/etc/network/interface` with something similar to the following:

```
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
iface eth0 inet static
address 10.127.45.122
netmask 255.255.255.0
gateway 10.127.45.1
dns-nameservers 10.127.45.9
```

Run `ifup eth0` to bring us onto the network.
It is recommend to ssh directly to the VM from this point on.

# Partition, Format, & Automount the secondary drive

```
parted --script /dev/sdb mklabel gpt
parted --script -a optimal /dev/sdb mkpart primary 0% 100%
mkfs -F -t ext4 -q /dev/sdb1
mkdir /data
mount /dev/sdb1 /data
echo "/dev/sdb1 /data ext4 defaults 0 2" >> /etc/fstab
```

# Install Docker

`apt-get install -y docker.io`

# Pull the containers needed to run bootstrap services (Minio S3, Gogs Git Repository & Docker Registry)
```
docker pull gogs/gogs:0.11.79
docker pull minio/minio:RELEASE.2019-01-16T21-44-08Z
docker pull registry:2.7.1
docker pull postgres:11.1
```

# Install the fly CLI for use later in the Pivotal Bootstrap systemd service
```
wget https://github.com/concourse/concourse/releases/download/v4.2.2/fly_linux_amd64 -O fly
chmod +x fly
mv fly /usr/bin/fly
```

# Install the Concourse Binary for use later in the Pivotal Bootstrap systemd service

```
wget https://github.com/concourse/concourse/releases/download/v4.2.2/concourse_linux_amd64 -O concourse
chmod +x concourse
mv concourse /usr/bin/concourse
```

# Setup Pivotal Bootstrap Systemd Service

- Place the following in `/etc/systemd/system/pivotal-bootstrap.service`
```
[Unit]
Description=Pivotal Bootstrap

[Service]
Type=forking
ExecStart=/usr/bin/pivotal-bootstrap

[Install]
WantedBy=multi-user.target
```

- Enable the systemd service to auto-start when vm boots
`systemctl enable pivotal-bootstrap`

- Configure the Pivotal bootstrap script by placing the either [pivotal-bootstrap.sh](pivotal-bootstrap.sh) or [cruise-pivotal-bootstrap.sh](cruise-pivotal-bootstrap.sh) in `/usr/bin/pivotal-bootstrap`

- Enable the script to be runable
`chmod +x /usr/bin/pivotal-bootstrap`

# Setup local files for inital deploy pipeline

- create directory `mkdir /data/pipelines`
- change directory `cd /data/pipelines`
- `git clone https://github.com/Oskoss/cowboy-pipelines.git`

# Add Pivotal Network Bits to Minio S3

Start Minio Manually

```
mkdir -p /data/minio
docker run -d \
    -p 9000:9000 \
    --restart=always \
    -e "MINIO_ACCESS_KEY=vcap" \
    -e "MINIO_SECRET_KEY=c1oudc0w" \
    -v /data/minio:/data \
    minio/minio:RELEASE.2019-01-16T21-44-08Z server /data
```

Navigate to the IP of the VM, port 9000
Create buckets:
 - harbor-container-registry
 - pivotal-container-service
 - pivotal-ops-manager
 - xenial-stemcells

Enable buckets to be read/write by everyone.

Upload artifacts.

# Pull, Tag, Push Images to Docker Registry running on OVA

Start Docker Registry Manually

```
mkdir -p /data/docker-registry
docker run -d \
    -p 5000:5000 \
    --restart=always \
    --name registry \
    -v /data/docker-registry:/var/lib/registry \
    registry:2.7.1
```

Move all images to docker-registry (if you do this locally you keep the bootstrap vm as lean as possible)

```
docker pull gcr.io/kubernetes-helm/tiller:v2.12.0
docker tag gcr.io/kubernetes-helm/tiller:v2.12.0 10.127.45.122:5000/kubernetes-helm/tiller:v2.12.0
docker push 10.127.45.122:5000/kubernetes-helm/tiller:v2.12.0
docker pull ubuntu:xenial
docker tag ubuntu:xenial 10.127.45.122:5000/ubuntu:xenial
docker push 10.127.45.122:5000/ubuntu:xenial
docker pull openjdk:8-jdk
docker tag openjdk:8-jdk 10.127.45.122:5000/openjdk:8-jdk
docker push 10.127.45.122:5000/openjdk:8-jdk
docker pull bitnami/zookeeper:3.4.13 
docker tag bitnami/zookeeper:3.4.13  10.127.45.122:5000/bitnami/zookeeper:3.4.13
docker push 10.127.45.122:5000/bitnami/zookeeper:3.4.13 
docker pull bitnami/cassandra:3.11.3
docker tag bitnami/cassandra:3.11.3  10.127.45.122:5000/bitnami/cassandra:3.11.3
docker push 10.127.45.122:5000/bitnami/cassandra:3.11.3 
docker pull bitnami/kafka:2.1.0
docker tag bitnami/kafka:2.1.0 10.127.45.122:5000/bitnami/kafka:2.1.0
docker push 10.127.45.122:5000/bitnami/kafka:2.1.0
docker pull concourse/concourse:4.2.2
docker tag concourse/concourse:4.2.2 10.127.45.122:5000/concourse/concourse:4.2.2
docker push 10.127.45.122:5000/concourse/concourse:4.2.2
docker pull oskoss/cowboy-pipelines:0.1
docker tag oskoss/cowboy-pipelines:0.1 10.127.45.122:5000/oskoss/cowboy-pipelines:0.1
docker push 10.127.45.122:5000/oskoss/cowboy-pipelines:0.1
docker pull traefik:1.7.7
docker tag traefik:1.7.7 10.127.45.122:5000/traefik:1.7.7
docker push 10.127.45.122:5000/traefik:1.7.7
docker pull postgres:9.6.2
docker tag postgres:9.6.2 10.127.45.122:5000/postgres:9.6.2
docker push 10.127.45.122:5000/postgres:9.6.2
```

# Sync the edge-platform repo to the OVA

Start Gogs (Git Registry) manually
 - start postgres
 - create gogs database in postgres
 - start gogs

```
mkdir -p /data/postgres
docker run -d \
    -p 5432:5432 \
    --restart=always \
    --name=postgres \
    -v /data/postgres:/data \
    -e PGDATA=/data \
    -e POSTGRES_USER=vcap \
    -e POSTGRES_PASSWORD=c1oudc0w \
    postgres:11.1

docker run \
-e "PGPASSWORD=c1oudc0w" \
postgres \
sh -c "psql -h 10.127.45.122 --username=vcap postgres -c 'CREATE DATABASE gogs'"

rm -rf /data/git/gogs-repositories
mkdir -p /data/gogs/gogs/conf
mkdir -p /data/git/gogs-repositories

cat << EOF > /data/gogs/gogs/conf/app.ini
APP_NAME = Pivotal-Bootstrap
RUN_USER = git
RUN_MODE = prod

[database]
DB_TYPE  = postgres
HOST     = 10.127.45.122:5432
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
    gogs/gogs:0.11.79
```

Create the vcap user

`docker exec gogs sh -c "su -c \"/app/gogs/gogs admin create-user --name=vcap --password=c1oudc0w --email=no-reply@pivotal.io --admin=true\" git"`


Login to Gogs (Git Registry) via the VM IP and port 3000

Create cowboy-pipelines repo

Add repo locally and push to the above local repo

```
cd /data/pipelines/cowboy-pipelines
git remote add local http://localhost:3000/vcap/cowboy-pipelines.git
git push local
```

# Free up space

- First on the root 10gb drive
```
dd if=/dev/zero of=/zeroes
rm -f /zeros
```

- Second on the data 110gb drive
```
dd if=/dev/zero of=/data/zeroes
rm -f /data/zeros
```

- Shutdown the VM

- SSH to the esxi server










