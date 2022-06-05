# cloud-init golden image builder
A demo showing how to use cloud-init to build golden images from Github Actions CI

## Files
- `app/`: A simple Python application for demo purposes
- `cloud-config/`: Terraform configuration for provisioning a basic web facing application on AWS using the build AMI
- `server-config/`: Configuration files for the VM image
- `run-aws.sh`: Build the golden image by running an EC2 instance on AWS
- `run-local.sh`: Build the golden image locally using qemu
- `run-logs-demo.sh`: Start an EC2 instance, connect with SSH, and show cloud-init logs. This shows what cloud-init processes are doing