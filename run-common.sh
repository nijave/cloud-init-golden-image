KEY_TYPE=ed25519
KEY_NAME=cloud-init

rm -f "${KEY_NAME}" "${KEY_NAME}.pub"
ssh-keygen -t $KEY_TYPE -f "${KEY_NAME}" -q -N ""
cat <<EOF | yq eval ".system_info.default_user.ssh_authorized_keys[0] = \"$(cat "${KEY_NAME}.pub")\"" | tee user-data
#cloud-config

system_info:
  default_user:
    name: cloudinit
    sudo: ALL=(ALL) NOPASSWD:ALL
runcmd:
  - [cd, /root]
  - [dnf, install, -y, https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.2.0-x86_64.rpm, bind-utils]
  - [sed, -Ei, 's/#?xpack\.security\.enabled.*/xpack.security.enabled: false/g', /etc/elasticsearch/elasticsearch.yml]
  - [cloud-init, clean, -l, -s]
  - [poweroff]
write_files:
  - encoding: b64
    owner: root:root
    permissions: '0755'
    path: /opt/elasticsearch-init.sh
    content: $(cat init.sh | base64 -w 0)
EOF
