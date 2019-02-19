#!/usr/bin/env bash
# ssh to undercloud as root and run this script
# it's probably easier to just copy/paste the contents of 0-site-settings into your terminal, then
# paste in the rest of this script.  This keeps you from having to clone down the entire repo for this simple bit.
source ~/pod4-osp-d/scripts/0-site-settings.sh

# register with satellite
echo "$satellite_server_ip $satellite_server.$domain $satellite_server" >> /etc/hosts
yum localinstall -y http://$satellite_server.$domain/pub/katello-ca-consumer-latest.noarch.rpm
subscription-manager register --org "$organization" --activationkey $activation_key
# subscription-manager register # just using my RH id/pw here
#subscription-manager attach --pool=$pool
#subscription-manager repos --disable "*"
#subscription-manager repos --enable=rhel-7-server-rpms \
#--enable=rhel-7-server-extras-rpms \
#--enable=rhel-7-server-rh-common-rpms \
#--enable=rhel-ha-for-rhel-7-server-rpms \
#--enable=rhel-7-server-openstack-13-rpms

# set hostname
hostnamectl set-hostname $hostname.$domain
echo "$ip_address $hostname.$domain $hostname" >> /etc/hosts

# add stack user
useradd stack
echo $stack_password | passwd stack --stdin
echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack

# install director installer package
yum install -y python-tripleoclient git gcc python-devel screen ceph-ansible

# update all packages and reboot
yum -y update && reboot

