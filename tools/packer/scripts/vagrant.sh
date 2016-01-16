#!/bin/bash -eux

echo '==> Configuring settings for ronin'

SSH_USER=${SSH_USER:-ronin}
SSH_USER_HOME=${SSH_USER_HOME:-/home/${SSH_USER}}
VAGRANT_INSECURE_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE7sWSZE9/RCDTB85MMOLKjycC7YNytog5X22kNkiORqQLNg9SoYiEGO5on+H6zuU2DRcXmhUse2OP4EgOLfvprTIkUQFjxpfXk1VrqHUPtdI2ikXpT2CGLP1Rce1f9KeGOi4P0gUpyM/8IromYATIE92LvjIkIVDTkMcEItrEMTd1OmAkVCnesA4jP8psMDYXsa7slPnnH7M6901EeR9OEQz4URnbuzm1MmWLB0ccKXJ0sIE7nsFc59NL9aqf+h4YP+kkZoMaOnZAWHiQmO+vOvSUnHT3UFkfFpNt7QtxMIRBM8AxAfI1F8yu097Gq2wtslfZ4TpC5pB7L6H+mS/D ronin insecure public key"

# Add vagrant user (if it doesn't already exist)
if ! id -u $SSH_USER >/dev/null 2>&1; then
    echo '==> Creating Ronin user'
    /usr/sbin/groupadd $SSH_USER
    /usr/sbin/useradd $SSH_USER -g $SSH_USER -G sudo -d $SSH_USER_HOME --create-home
    echo "${SSH_USER}:${SSH_USER}" | chpasswd
fi

# Set up sudo.  Be careful to set permission BEFORE copying file to sudoers.d
( cat <<EOP
%$SSH_USER ALL=(ALL) NOPASSWD:ALL
EOP
) > /tmp/ronin
chmod 0440 /tmp/ronin
mv /tmp/ronin /etc/sudoers.d/

# Packer passes boolean user variables through as '1', but this might change in
# the future, so also check for 'true'.
if [ "$INSTALL_VAGRANT_KEY" = "true" ] || [ "$INSTALL_VAGRANT_KEY" = "1" ]; then
    echo '==> Installing Vagrant SSH key'
    mkdir -pm 700 $SSH_USER_HOME/.ssh
    # https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
    echo "${VAGRANT_INSECURE_KEY}" > $SSH_USER_HOME/.ssh/authorized_keys
    chmod 600 $SSH_USER_HOME/.ssh/authorized_keys
    chown -R $SSH_USER:$SSH_USER $SSH_USER_HOME/.ssh
fi
