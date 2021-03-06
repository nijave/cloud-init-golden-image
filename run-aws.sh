#!/bin/bash

set -euxo pipefail

. server-config/run-common.sh

# Get vpc-id
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[0].SubnetId' --output text)

# Get security-group id
SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --group-names "default" --query "SecurityGroups[0].GroupId" --output text)

# Find the correct image id using Alma Linux's published list
IMAGE_ID=$(curl -s https://wiki.almalinux.org/ci-data/aws_amis.csv | grep "$AWS_DEFAULT_REGION" | grep x86_64 | grep -v beta | head -n 1 | awk -F, '{print $4}' | tr -d '"')

# Create ec2 instance
EC2_ID=$(
  aws ec2 run-instances \
    --image-id $IMAGE_ID \
    --instance-type t3.small \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --user-data "$(cat user-data)" \
    --tag-specifications \
      'ResourceType=instance,Tags=[{Key=Owner,Value=ci-image-build}]' \
      'ResourceType=network-interface,Tags=[{Key=Owner,Value=ci-image-build}]' \
      'ResourceType=volume,Tags=[{Key=Owner,Value=ci-image-build}]' \
    --query 'Instances[0].InstanceId' \
    --output text
)

# Wait 10 minutes for completion
tries=10
while [ $(aws ec2 describe-instances --query 'Reservations[0].Instances[0].State.Name' --output text --instance-ids $EC2_ID) != "stopped" ]; do
  sleep 60
  tries=$((tries-1))
  if [ $tries -eq 0 ]; then
    echo "Instance didn't shutdown before timeout" 2>&1
    aws ec2 stop-instances --instance-ids $EC2_ID
    exit 1
  fi
done

# Create an image from the EC2 instance
AMI_ID=$(
  aws ec2 create-image \
    --instance-id $EC2_ID \
    --name $(date +%Y-%m-%d-%H-%M)-cloud-init-demo-elasticsearch \
    --tag-specifications 'ResourceType=image,Tags=[{Key=Owner,Value=ci-image-build}]' \
    --query 'ImageId' \
    --output text
)

# Capture the image id as a Github Actions output variable
echo "::set-output name=AMI_ID::$AMI_ID"

aws ec2 terminate-instances \
  --instance-ids $EC2_ID

aws ec2 describe-images \
  --image-ids $AMI_ID

# Store the image id in Parameter Store so other systems can find it
aws ssm put-parameter \
  --name /images/python-application/dev \
  --value $AMI_ID \
  --description "CI golden image for python-application" \
  --type String \
  --overwrite

# If you need to restart the instance to troubleshoot/debug, clear
# existing user-data so it doesn't re-run
# aws ec2 modify-instance-attribute --user-data "" --instance-id
