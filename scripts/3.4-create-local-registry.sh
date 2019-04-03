time openstack overcloud container image prepare \
  --namespace=registry.access.redhat.com/rhosp13 \
  --push-destination=192.168.66.18:8787 \
  --prefix=openstack- \
  --tag-from-label {version}-{release} \
  --set ceph_namespace=registry.access.redhat.com/rhceph \
  --set ceph_image=rhceph-3-rhel7 \
  --set ceph_tag=latest \
  -r /home/stack/templates/environments/roles_data.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-sriov.yaml \
  --output-env-file=/home/stack/templates/overcloud_images.yaml \
  --output-images-file /home/stack/local_registry_images.yaml

#openstack overcloud container image prepare --namespace=registry.access.redhat.com/rhosp13 --push-destination=192.168.86.18:8787 --prefix=openstack- --tag-from-label {version}-{release} -r /home/stack/templates/environments/roles_data.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-sriov.yaml --set ceph_namespace=registry.access.redhat.com/rhceph --set ceph_image=rhceph-3-rhel7 --set ceph_tag=latest --output-env-file=/home/stack/templates/overcloud_images.yaml --output-images-file /home/stack/local_registry_images.yaml
