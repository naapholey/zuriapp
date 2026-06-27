#!/bin/bash

set -euxo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data)
exec 2>&1

echo "Starting K3s installation..."

##############################################################
# Install packages
##############################################################

apt-get update

apt-get install -y \
    curl \
    unzip \
    jq

##############################################################
# Install AWS CLI v2
##############################################################

cd /tmp

curl -s \
https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
-o awscliv2.zip

unzip -q awscliv2.zip

./aws/install

##############################################################
# Install K3s
##############################################################

curl -sfL https://get.k3s.io | \
INSTALL_K3S_CHANNEL=${k3s_version} sh -

##############################################################
# Wait for service
##############################################################

until systemctl is-active --quiet k3s
do
    sleep 5
done

##############################################################
# Wait for kubeconfig
##############################################################

until [ -f /etc/rancher/k3s/k3s.yaml ]
do
    sleep 5
done

# Wait for the EC2 metadata service to become available
until curl -fs http://169.254.169.254/latest/meta-data/public-ipv4 >/dev/null; do
    sleep 2
done

TOKEN=$(curl -X PUT \
http://169.254.169.254/latest/api/token \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -fs \
  -H "X-aws-ec2-metadata-token: $${TOKEN}" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

PRIVATE_IP=$(curl -fs \
  -H "X-aws-ec2-metadata-token: $${TOKEN}" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Public IP: $${PUBLIC_IP}"
echo "Private IP: $${PRIVATE_IP}"
##############################################################
# IMDSv2
##############################################################


##############################################################
# Replace localhost
##############################################################

sed "s/127.0.0.1/$${PUBLIC_IP}/g" \
/etc/rancher/k3s/k3s.yaml \
> /tmp/k3s-config

##############################################################
# Upload to Secrets Manager
##############################################################

aws secretsmanager put-secret-value \
    --secret-id "${secret_name}" \
    --secret-string file:///tmp/k3s-config \
    --region "${region}"

echo "Bootstrap complete."