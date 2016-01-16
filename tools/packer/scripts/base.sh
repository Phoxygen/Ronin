USER=ronin
HOME=/home/$USER
echo "update and upgrading"
apt-get update
apt-get -y upgrade
echo "install Ronin and its dependencies"
apt-get -y install xinit nodejs npm super
cd /tmp
wget https://s3.eu-central-1.amazonaws.com/ronin-os/ronin-os-latest.deb
dpkg -i ronin-os-latest.deb 
apt-get -fy install
echo "wetty.conf"
sed -i -e "s/exec/exec setuid 1000/" /etc/init/ronin.conf
ID=id
echo "mon id est $ID"
sudo mv /etc/init/ronin.conf /etc/init/wetty.conf
wget -O /etc/init/ronin.conf https://raw.githubusercontent.com/Phoxygen/Ronin/tools/tools/packer/scripts/ronin.conf

echo "Add ronin user to passwordless sudo"
sed -i -e 's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers

echo "UseDNS no" >> /etc/ssh/sshd_config

echo "Install ronin ssh key"
mkdir $HOME/.ssh
wget --no-check-certificate -O $HOME/.ssh/authorized_keys 'https://raw.githubusercontent.com/Phoxygen/Ronin/tools/tools/vagrant/.ssh/id_rsa.pub'

ssh-keygen -f $HOME/.ssh/id_rsa -q -N ""
cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
chown -R ronin $HOME/.ssh
chmod -R go-rwsx $HOME/.ssh
rm -fr $HOME/tmp
