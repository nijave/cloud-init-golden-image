#!/bin/bash

set -eux

KEY_NAME=${HOSTNAME}-ed25519

# Find the default VPC on AWS
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
# Fund the first subnet in the default VPC
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[0].SubnetId' --output text)

# Get security-group id
SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --group-names "default" --query "SecurityGroups[0].GroupId" --output text)

# Create a key named after the host if one doesn't already exist
test -f "$KEY_NAME" || ssh-keygen -t ed25519 -f "${KEY_NAME}" -q -N ""
aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material "$(cat "${KEY_NAME}.pub")" || true
EC2_ID=$(
    aws ec2 run-instances \
    --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2 \
    --instance-type a1.medium \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --query 'Instances[0].InstanceId' \
    --key-name "$KEY_NAME" \
    --user-data "#\!/bin/bash\necho 'Hello cloud-init'" \
    --output text
)

#  Wait for the instance to power up and grab the public IP
while true; do
    IP=$(aws ec2 describe-instances --instance-ids $EC2_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "$IP" | grep -qE '[0-9]+[.]?' && break
    sleep 1
done

# Keep trying to SSH to the instance until it succeeds
while true; do
    # Connect to the test instance and show the cloud-init.log with some relevant items
    # highlighted
    ssh -t -i "$KEY_NAME" \
        -o ConnectTimeout=2 \
        -o ConnectionAttempts=60 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=no \
        ec2-user@$IP "sudo grep --color=always -e 'init-local' -e 'init-network' -e 'Running command' -e ^ </var/log/cloud-init.log | less -r" \
        && break

    sleep 2
done

aws ec2 terminate-instances --instance-ids $EC2_ID --output text
