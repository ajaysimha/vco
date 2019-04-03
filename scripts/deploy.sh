#!/usr/bin/env bash
if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

source ~//scripts/0-site-settings.sh
log_time=`date +%s`
echo $log_time

source ~/stackrc
cd ~
time openstack overcloud deploy \
    --templates --timeout 90 \
    --stack $stack_name \
    -r ~/templates/environments/roles_data.yaml \
    -n ~/templates/network_data.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/host-config-and-reboot.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-sriov.yaml \
    -e ~/templates/environments/network-environment.yaml \
    -e ~/templates/overcloud_images.yaml \
    -e ~/templates/environments/pod-environment.yaml  \
     | tee overcloud-install.log.$log_time
