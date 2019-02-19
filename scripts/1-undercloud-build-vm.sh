#!/usr/bin/env bash

source ~/pod4-osp-d/scripts/0-site-settings.sh

# install necessary packages and start up libvirt
yum install -y  libguestfs-tools libvirt qemu-kvm \
   virt-manager virt-install xorg-x11-apps xauth virt-viewer libguestfs-xfs
systemctl enable libvirtd && systemctl start libvirtd

#create empty qcow2 file for a base image
cd /var/lib/libvirt/images
qemu-img create -f qcow2 rhel7-guest.qcow2 200G

#find guest_image_name
guest_image_name="rhel-server-7.5-x86_64-kvm.qcow2"

#user virt-resize to dump the guest image into the qcow2 file we just created.
virt-resize --expand /dev/sda1 $guest_image_name rhel7-guest.qcow2

# create a clone of the base image and use it for the undercloud
qemu-img create -f qcow2 -b rhel7-guest.qcow2 undercloud.qcow2

# remove cloud-init (causes delays and problems when not used on a cloud)
virt-customize -a undercloud.qcow2 --run-command 'yum remove cloud-init* -y' --root-password password:redhat


# Create undercloud guest VM eth0 file
virt-customize -a undercloud.qcow2 --run-command 'cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE="eth0"
ONBOOT="yes"
TYPE="Ethernet"
PEERDNS="yes"
IPV6INIT="no"
IPADDR=10.12.134.20
NETMASK=255.255.255.0
GATEWAY=10.12.134.254
DNS1=10.12.32.1
EOF'

# Create undercloud guest VM eth1 file
virt-customize -a undercloud.qcow2 --run-command 'cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE="eth1"
ONBOOT="yes"
TYPE="Ethernet"
PEERDNS="no"
IPV6INIT="no"
IPADDR=10.12.34.20
NETMASK=255.255.255.0
EOF'

# build undercloud VM
virt-install --ram 16000 --vcpus 4 --os-variant rhel7 \
    --disk path=/var/lib/libvirt/images/undercloud.qcow2,device=disk,bus=virtio,format=qcow2 \
    --import --noautoconsole --vnc \
    --bridge  brpublic \
    --name undercloud
#     --network  type=direct,source=em1,source_mode=bridge \

# create a clone of the base image and use it for the logger vm
#qemu-img create -f qcow2 -b rhel7-guest.qcow2 logmon.qcow2
#
## remove cloud-init (causes delays and problems when not used on a cloud)
#virt-customize -a logmon.qcow2 --run-command 'yum remove cloud-init* -y'
#
## set root pw
#virt-customize -a logmon.qcow2 --root-password password:redhat

## Create logmon guest VM eth0 file
#virt-customize -a logmon.qcow2 --run-command 'cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
#DEVICE="eth0"
#ONBOOT="yes"
#TYPE="Ethernet"
#PEERDNS="yes"
#IPV6INIT="no"
#IPADDR=10.12.36.8
#NETMASK=255.255.255.0
#GATEWAY=10.12.36.254
#DNS1=10.12.32.1
#EOF'
#
#virt-customize -a logmon.qcow2 --run-command 'cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
#DEVICE="eth1"
#ONBOOT="yes"
#TYPE="Ethernet"
#PEERDNS="no"
#IPV6INIT="no"
#IPADDR=10.12.136.8
#NETMASK=255.255.255.0
#EOF'
#
## build logmon VM
#virt-install --ram 8096 --vcpus 4 --os-variant rhel7 \
#    --disk path=/var/lib/libvirt/images/logmon.qcow2,device=disk,bus=virtio,format=qcow2 \
#    --import --noautoconsole --vnc \
#    --network  type=direct,source=em1,source_mode=bridge \
#    --network  type=direct,source=em1.1136,source_mode=bridge \
#    --name logmon
#
#
