#!/bin/bash -x
if [ ! -e /home/ronin/.vbox_version ]; then
    exit 0
fi

VBOX_VERSION=5.0
VBOX_ISO=/home/ronin/VBoxGuestAdditions.iso

apt-get -y install linux-headers-$(uname -r) build-essential dkms

#if [ ! -f $VBOX_ISO ]; then
#    wget http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso -O $VBOX_ISO
    wget http://download.virtualbox.org/virtualbox/5.0.0_RC3/VBoxGuestAdditions_5.0.0_RC3.iso -O $VBOX_ISO 
#fi

mount -o loop $VBOX_ISO /mnt
sh /mnt/VBoxLinuxAdditions.run
umount /mnt

rm $VBOX_ISO
