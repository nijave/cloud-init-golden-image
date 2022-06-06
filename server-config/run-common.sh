KEY_TYPE=ed25519
KEY_NAME=cloud-init

rm -f "${KEY_NAME}" "${KEY_NAME}.pub"
ssh-keygen -t $KEY_TYPE -f "${KEY_NAME}" -q -N ""
cat <<EOF | yq eval ".system_info.default_user.ssh_authorized_keys[0] = \"$(cat "${KEY_NAME}.pub")\"" | tee user-data
#cloud-config

system_info:
  default_user:
    name: ec2-user
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
    content: $(base64 -w 0 < server-config/python-application.service)
  - encoding: b64
    owner: root:root
    permissions: '0644'
    path: /etc/nginx/nginx.conf
    content: $(base64 -w 0 < server-config/nginx.conf)
  - encoding: b64
    owner: root:root
    permissions: '0644'
    path: /opt/app.tar.gz
    content: $(tar cf - app | gzip -9 | base64 -w 0)
  - path: /etc/chrony.conf
    append: true
    content: |
      server 169.254.169.123 prefer iburst auto_offline
runcmd:
  - [dnf, install, -y, epel-release]
  - [dnf, upgrade, -y]
  - [dnf, module, enable, -y, nginx:1.20]
  - [dnf, install, -y, firewalld, nginx, python39, https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm]
  - [setsebool, -P, httpd_can_network_connect, 1]
  - [firewall-offline-cmd, --add-service=ssh]
  - [firewall-offline-cmd, --add-service=http]
  - [tar, xf, /opt/app.tar.gz, -C, /opt/app, --strip-components, 1]
  - [su, app, -c, python3.9 -m pip install --user -r /opt/app/requirements.txt]
  - [systemctl, enable, nginx]
  - [systemctl, enable, python-application]
  - [systemctl, enable, firewalld]
  - [systemctl, enable, amazon-ssm-agent]
  - [rm, -f, /home/ec2-user/.ssh/authorized_keys]
  - [cloud-init, clean, -l, -s]
  - [poweroff]
EOF
