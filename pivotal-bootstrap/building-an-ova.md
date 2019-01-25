
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

# Add Pivotal Network Bits to Minio S3

Navigate to the IP of the VM, port 9000
Create buckets:
 - harbor-container-registry
 - pivotal-container-service
 - pivotal-ops-manager
 - xenial-stemcells

Enable buckets to be read/write by everyone.

Upload artifacts.

# Pull, Tag, Push Images to Docker Registry running on OVA

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
docker pull bitnami/zookeeper:3.4.13 
docker tag bitnami/zookeeper:3.4.13  10.127.45.122:5000/bitnami/cassandra:3.11.3
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

# Sync the edge-platform repo to the OVA

Login to Gogs (Git Registry) via the VM IP and port 3000

- change directory into `/data/pipelines`
- `git clone https://github.com/Oskoss/cowboy-pipelines.git`

