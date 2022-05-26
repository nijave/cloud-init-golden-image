#!/bin/bash
# https://access.cdn.redhat.com/content/origin/files/sha256/92/92862e085e4d5690cfa57de7155aa29bfdf21feec3d46dd4b61ca63293312af7/rhel-baseos-9.0-x86_64-kvm.qcow2?user=91cc81b931555835cd0dc30a6486d1f4&_auth_=1653170110_83639965ce860b2f893687c06c24e53e

set -x

IMAGE_NAME=AlmaLinux-8-GenericCloud-latest.x86_64.qcow2
# IMAGE_NAME=rhel-baseos-9.0-x86_64-kvm.qcow2
KEY_TYPE=ed25519
KEY_NAME=cloud-init
export AWS_DEFAULT_REGION=us-east-2

cp ~/Downloads/${IMAGE_NAME} .
rm -f "${KEY_NAME}" "${KEY_NAME}.pub"
ssh-keygen -t $KEY_TYPE -f "${KEY_NAME}" -q -N ""
#cloud-init devel schema --config-file user-data
cat <<EOF | yq eval ".system_info.default_user.ssh_authorized_keys[0] = \"$(cat "${KEY_NAME}.pub")\"" | tee user-data
#cloud-config

system_info:
  default_user:
    name: cloudinit
    sudo: ALL=(ALL) NOPASSWD:ALL
runcmd:
  - [cd, /root]
  - [dnf, install, -y, https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.2.0-x86_64.rpm]
  - [sed, -Ei, 's/#?xpack\.security\.enabled.*/xpack.security.enabled: false/g', /etc/elasticsearch/elasticsearch.yml]
  - [cloud-init, clean, -l, -s]
  - [poweroff]
EOF

cat <<EOF | tee meta-data
instance-id: abc123
local-hostname: elasticsearch
EOF

# xorriso -as genisoimage -output cloud-init.iso -volid CIDATA -joliet -rock user-data meta-data

# qemu-system-x86_64 \
#   -drive file=${IMAGE_NAME} \
#   -drive file=cloud-init.iso,media=cdrom \
#   -cpu host \
#   -m 1G -machine type=q35,accel=kvm \
#   -nic user,hostfwd=tcp::60022-:22 \
#   -serial mon:stdio -nographic

# Check if key exists, create
# if ! KEY_ID=$(aws ec2 describe-key-pairs --key-names "$KEY_NAME" --query "KeyPairs[0].KeyPairId" --output text 2>/dev/null); then
#   KEY_ID=$(
#       aws ec2 import-key-pair \
#       --key-name "$KEY_NAME" \
#       --public-key-material "$(cat "${KEY_NAME}.pub")" \
#         | jq -r '.KeyPairId'
#   )
# fi

# aws ec2 delete-key-pair --key-name "$KEY_NAME"

# Get vpc-id
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[0].SubnetId' --output text)

# Get security-group id
SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --group-names "default" --query "SecurityGroups[0].GroupId" --output text)

IMAGE_ID=$(curl -s https://wiki.almalinux.org/ci-data/aws_amis.csv | grep "$AWS_DEFAULT_REGION" | grep x86_64 | grep -v beta | head -n 1 | awk -F, '{print $4}' | tr -d '"')

# Create ec2 instance
#     --key-name $KEY_NAME \
EC2_ID=$(
  aws ec2 run-instances \
    --image-id $IMAGE_ID \
    --instance-type t3.small \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --user-data "$(cat user-data)" \
    --query 'Instances[0].InstanceId' \
    --output text
)

# Wait 10 minutes for completion
tries=10
while [ $(aws ec2 describe-instances --query 'Reservations[0].Instances[0].State.Name' --output text --instance-id i-097f1a44768510120) != "stopped" ]; do
  sleep 60
  tries=$((tries-1))
  if [ $tries -eq 0 ]; then
    echo "Instance didn't shutdown before timeout" 2>&1
    aws ec2 stop-instances --instance-ids $EC2_ID
    break
  fi
done

# ssh -i cloud-init -p 60022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -vv cloudinit@localhost
# /var/lib/cloud/instances/abc123/scripts/runcmd
# /var/lib/cloud/instance/scripts/runcmd