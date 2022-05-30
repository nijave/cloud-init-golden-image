#!/bin/bash

set -eux

KEY_NAME=${HOSTNAME}-ed25519
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[0].SubnetId' --output text)

# Get security-group id
SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --group-names "default" --query "SecurityGroups[0].GroupId" --output text)

# --iam-instance-profile Name=AmazonSSMManagedInstanceCore \
aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material "$(cat ~/.ssh/id_ed25519.pub)" || true
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

while true; do
    IP=$(aws ec2 describe-instances --instance-ids $EC2_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "$IP" | grep -qE '[0-9]+[.]?' && break
    sleep 1
done

while true; do
    ssh -t -i ~/.ssh/id_ed25519 \
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