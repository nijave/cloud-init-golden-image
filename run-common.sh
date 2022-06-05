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
users:
  - default
  - name: app
    gecos: Python app user
    lock_passwd: true
    homedir: /opt/app
    ssh_authorized_keys: []
write_files:
  - encoding: b64
    owner: root:root
    permissions: '0644'
    path: /etc/systemd/system/python-application.service
    content: $(cat python-application.service | base64 -w 0)
  - encoding: b64
    owner: root:root
    permissions: '0644'
    path: /etc/nginx/nginx.conf
    content: $(cat nginx.conf | base64 -w 0)
  - encoding: b64
    owner: root:root
    permissions: '0644'
    path: /opt/app.tar.gz
    content: $(tar cf app.tar app && gzip -f -9 app.tar && base64 -w 0 <app.tar.gz)
  - path: /etc/chrony.conf
    append: true
    content: |
      server 169.254.169.123 prefer iburst auto_offline
runcmd:
  - [dnf, install, -y, epel-release]
  - [dnf, upgrade, -y]
  - [dnf, module, enable, -y, nginx:1.20]
  - [dnf, install, -y, firewalld, nginx, python39]
  - [setsebool, -P, httpd_can_network_connect, 1]
  - [firewall-offline-cmd, --add-service=http]
  - [tar, xf, /opt/app.tar.gz, -C, /opt]
  - [su, app, -c, python3.9 -m pip install --user -r /opt/app/requirements.txt]
  - [systemctl, enable, nginx]
  - [systemctl, enable, python-application]
  - [systemctl, enable, firewalld]
  - [cloud-init, clean, -l, -s]
  - [poweroff]
EOF
