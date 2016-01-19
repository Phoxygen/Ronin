#!/usr/bin/env bash
#Install ronin ssh key
mkdir /home/ronin/.ssh
wget --no-check-certificate -O /home/ronin/.ssh/authorized_keys 'https://raw.githubusercontent.com/Phoxygen/Ronin/tools/tools/vagrant/.ssh/id_rsa.pub'
chown -R ronin /home/ronin/.ssh
chmod -R go-rwsx /home/ronin/.ssh

#Add ronin user to passwordless sudo
#cp /etc/sudoers{,.orig}
sed -i -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers
