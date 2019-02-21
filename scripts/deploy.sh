#!/usr/bin/env bash
if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

source ~//scripts/0-site-settings.sh

source ~/stackrc
cd ~
time openstack overcloud deploy --templates \
    --stack $stack_name \
    -n ~/templates/network_data.yaml \
    -e ~/templates/environments/network-environment.yaml \
    -e ~/templates/environments/overcloud-images.yaml \
    -e ~/templates/environments/pod2-environment.yaml 


#    -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
