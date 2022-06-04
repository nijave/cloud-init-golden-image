#!/bin/bash
# https://access.cdn.redhat.com/content/origin/files/sha256/92/92862e085e4d5690cfa57de7155aa29bfdf21feec3d46dd4b61ca63293312af7/rhel-baseos-9.0-x86_64-kvm.qcow2?user=91cc81b931555835cd0dc30a6486d1f4&_auth_=1653170110_83639965ce860b2f893687c06c24e53e

set -eux

BASE_IMAGE_NAME=AlmaLinux-8-GenericCloud-latest.x86_64.qcow2
NEW_IMAGE_NAME=cloud-init-demo.qcow2

test -f $BASE_IMAGE_NAME || wget https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2

. run-common.sh

cat <<EOF | tee meta-data
instance-id: abc123
local-hostname: elasticsearch
EOF

cp $BASE_IMAGE_NAME $NEW_IMAGE_NAME
xorriso -as genisoimage -output cloud-init.iso -volid CIDATA -joliet -rock user-data meta-data

  -drive file=cloud-init.iso,media=cdrom \
qemu-system-x86_64 \
  -drive file=$NEW_IMAGE_NAME \
  -cpu host \
  -m 1G -machine type=q35,accel=kvm \
  -nic user,hostfwd=tcp::60022-:22 \
  -serial mon:stdio -nographic

# ssh -i cloud-init -p 60022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 -o ConnectionAttempts=60 cloudinit@localhost
# /var/lib/cloud/instances/abc123/scripts/runcmd
# /var/lib/cloud/instance/scripts/runcmd