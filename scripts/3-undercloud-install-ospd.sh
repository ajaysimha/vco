#!/usr/bin/env bash
# after reboot
# run as STACK user su - stack

source ~/pod2-osp-d/scripts/0-site-settings.sh

# are we root?  that's bad
if [[ $EUID -eq 0 ]]; then
  echo "Do not run as root; su - stack" 2>&1
  exit 1
fi

# we store files in git that need to be in the
# stack users home directory, fetch them out
cp ~/pod2-osp-d/stack-home/* ~

if [ ! -f /home/stack/undercloud.conf ] ; then echo "No undercloud.conf" ; exit 1 ; fi


# Install openstack undercloud
cd ~
openstack undercloud install

if [ ! -f /home/stack/stackrc ] ; then  echo "No stackrc, undercloud deploy may have failed" ; exit 2 ; fi
source ~/stackrc

###########################
# Install Director Images #
###########################
sudo yum install -y rhosp-director-images rhosp-director-images-ipa

#############################
# Make Local Copy of Images #
#############################
mkdir -p ~/images
pushd ~/images
for i in /usr/share/rhosp-director-images/overcloud-full-latest-13.0.tar /usr/share/rhosp-director-images/ironic-python-agent-latest-13.0.tar; do
	tar -xvf $i;
done
popd

###########################
# Upload Images to Glance #
###########################
openstack overcloud image upload --image-path /home/stack/images/ --update-existing

##################################
## get docker images
## testing using satellite for imagemgmt
#################################
#openstack overcloud container image prepare \
#  --namespace=rhosp13 \
#  --prefix=openstack- \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/octavia.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/ironic.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/ironic-inspector.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/disable-telemetry.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/inject-trust-anchor.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-rgw.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
#  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/cinder-backup.yaml \
#  --set ceph_namespace=rhceph \
#  --set ceph_image=rhceph-3-rhel7 \
#  --set ceph_tag=latest \
#  --output-images-file /home/stack/satellite_images

# remove yaml specific info from import file
awk -F ':' '{if (NR!=1) {gsub("[[:space:]]", ""); print $2}}' ~/satellite_images > ~/satellite_images_names

# stop here the rest are notes for getting container images onto sat server
exit 0

# now copy the satellite_images_names file to the sat 6 server and run the following:
scp ~/satellite_images_names root@10.12.134.15:

# execute these from the satellite server after configuring hammer for passwordless operation:
# https://access.redhat.com/solutions/1612123

hammer product create \
--organization "pod2" \
--name "osp13 containers"

hammer repository create \
--organization "pod2" \
--product "osp13 containers" \
--content-type docker \
--url https://registry.access.redhat.com \
--docker-upstream-name rhosp13/openstack-base \
--name base

while read IMAGE; do \
  IMAGENAME=$(echo $IMAGE | cut -d"/" -f2 | sed "s/openstack-//g" | sed "s/:.*//g") ; \
  hammer repository create \
  --organization "pod2" \
  --product "osp13 containers" \
  --content-type docker \
  --url https://registry.access.redhat.com \
  --docker-upstream-name $IMAGE \
  --name $IMAGENAME ; done < satellite_images_names

hammer product synchronize \
--organization "pod2" \
--name "osp13 containers"

# list tags - this isn't really practical as of osp 13 as each image can have it's own release tag instead of
# being relased as a set.
#hammer docker tag list --repository "base" \
#  --organization "pod2" \
#  --product "osp13 containers"

# This will create the overcloud_images.yaml file with a list of static tagged images, derrived from the
# latest tag when the script is run
openstack overcloud container image prepare \
  --namespace=10.12.134.15:5000 \
  --prefix=pod2-dev-osp13-osp13_containers- \
  --tag latest \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/octavia.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/ironic.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/ironic-inspector.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/disable-telemetry.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ssl/inject-trust-anchor.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-rgw.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
  -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/cinder-backup.yaml \
  --set ceph_namespace=10.12.134.15:5000 \
  --set ceph_image=pod2-dev-osp13-osp13_containers-rhceph-3-rhel7 \
  --set ceph_tag=latest \
  --output-env-file=/home/stack/pod2-osp-d/templates/environments/overcloud-images.yaml
  
  # if we want to see all available images for rhosp13 in cdn, we could do this:
  # http://registry.access.redhat.com/v1/search?q=rhosp13