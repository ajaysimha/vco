#!/usr/bin/env bash
if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

source ~/pod2-osp-d/scripts/0-site-settings.sh

source ~/stackrc
cd ~
time openstack overcloud deploy --templates \
    --stack $stack_name \
    --ntp-server $ntp_server \
    -n ~/pod2-osp-d/templates/network_data.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/octavia.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/ironic.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/ironic-inspector.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/disable-telemetry.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/inject-trust-anchor.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/cinder-backup.yaml \
    -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-rgw.yaml \
    -e ~/pod2-osp-d/templates/environments/ceph-config.yaml \
    -e ~/pod2-osp-d/templates/environments/network-environment.yaml \
    -e ~/pod2-osp-d/templates/environments/overcloud-images.yaml \
    -e ~/pod2-osp-d/templates/environments/pod2-environment.yaml


#    -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
