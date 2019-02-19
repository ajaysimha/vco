#!/usr/bin/env bash

source ~/pod2-osp-d/scripts/0-site-settings.sh
source ~/stackrc
controllerCtlPlaneIps=($(nova list | awk '/controller/ {print $12}' | sed s/ctlplane=//g))
allCtlPlaneIps=($(nova list | awk '/ACTIVE/ {print $12}' | sed s/ctlplane=//g))

# become admin user
source $rcfile

for i in ${allCtlPlaneIps[@]} ; do
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo yum localinstall -y http://$satellite_server/pub/katello-ca-consumer-latest.noarch.rpm ; sudo subscription-manager register --org $organization --activationkey $activation_key"
done


########################
# Create default Openshift Project
openstack project create  openshift
openstack user create --project openshift --password redhat openshift
openstack role add --project openshift --user openshift _member_
#openstack role add --project openshift --user openshift swiftoperator
openstack role add --project openshift --user admin _member_

# create heat_stack_owner role:
openstack role create heat_stack_owner
openstack role add --project openshift --user openshift heat_stack_owner

# Load images
cd ~/images
#curl -O http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
##curl -O $webserver_url/rhel-guest-image-7.1-20150224.0.x86_64.qcow2
#curl -O http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2


openstack image create --public --file ~/images/CentOS-7-x86_64-GenericCloud.qcow2 --disk-format qcow2 --container bare centos7
openstack image create --public --file ~/images/cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container bare cirros
openstack image create --public --file ~/images/rhel-server-7.5-x86_64-kvm.qcow2 --disk-format qcow2 --container bare rhel75

#sleep 5
#rm -f cirros-0.3.5-x86_64-disk.img rhel-guest-image-7.1-20150224.0.x86_64.qcow2 CentOS-7-x86_64-GenericCloud.qcow2c

# Create Public network #need this vlan for openshift-net
#openstack network create --no-share --external --project service \
#  --provider-physical-network datacentre --provider-network-type vlan --provider-segment 1134 public
#openstack subnet create --allocation-pool start=10.12.134.51,end=10.12.134.100 \
#  --ip-version 4 --subnet-range 10.12.134.0/24 --no-dhcp --gateway 10.12.134.254 --network public public-subnet

# create openshift/baremetal network
openstack network create --no-share --project openshift \
  --provider-physical-network datacentre --provider-network-type vlan --provider-segment 1134 openshift-net

# use care not to overlap the ip range given to the undercloud for this network.
openstack subnet create --allocation-pool start=10.12.134.101,end=10.12.134.174 \
  --ip-version 4 --subnet-range 10.12.134.0/24 --dns-nameserver 10.12.134.50 --dns-nameserver 10.12.134.51 --gateway 10.12.134.254 --network openshift-net openshift-subnet --project openshift
#openstack router create --project openshift openshift-router
#openstack router add subnet openshift-router openshift-subnet
#openstack router set --external-gateway public openshift-router


# create flavors
# virtual
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack flavor set m1.tiny --property baremetal=false
openstack flavor create --ram 2048 --disk 20 --vcpus 1 m1.small
openstack flavor set m1.small --property baremetal=false
openstack flavor create --ram 4096 --disk 40 --vcpus 2 m1.medium
openstack flavor set m1.medium --property baremetal=false
# baremetal
openstack flavor create --ram 4096 --disk 35 --vcpus 2 baremetal
openstack flavor set baremetal --property baremetal=true

# octavia - set to baremetal false
openstack flavor set octavia_65 --property baremetal=false

#####################################
# create host aggregates            #
# to separate vm hosts (computes)   #
# vs baremetal hosts (controllers)  #
#####################################
openstack aggregate create --property baremetal=true --zone baremetal baremetal-hosts
openstack aggregate create --property baremetal=false virtual-hosts
# add computes
for vm_host in $(openstack hypervisor list -f value -c "Hypervisor Hostname" | grep compute); do
 openstack aggregate add host virtual-hosts $vm_host
done
# add controllers
for i in {0..2}; do openstack aggregate add host baremetal-hosts overcloud-controller-$i.localdomain; done


# complete ironic setup
# upload images for baremetal nodes
openstack image create --public --container-format aki --disk-format aki --file ~/images/ironic-python-agent.kernel deploy-kernel
openstack image create --public --container-format ari --disk-format ari --file ~/images/ironic-python-agent.initramfs deploy-ramdisk

cleaningnet=$(openstack network show openshift-net -f value -c id)
for i in ${controllerCtlPlaneIps[@]} ;do
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo crudini --set /var/lib/config-data/puppet-generated/ironic/etc/ironic/ironic.conf neutron cleaning_network $cleaningnet;sudo docker restart ironic_conductor"
done
echo  ""
echo "Set IronicCleaningNetwork in templates to $cleaningnet"
echo ""

#create an image for baremtal nodes TODO: replace with custom image for OCP
KERNEL_ID=$(openstack image create --file ~/images/overcloud-full.vmlinuz --public --container-format aki --disk-format aki -f value -c id overcloud-full.vmlinuz)
RAMDISK_ID=$(openstack image create --file ~/images/overcloud-full.initrd --public --container-format ari --disk-format ari -f value -c id overcloud-full.initrd)
openstack image create --file ~/images/overcloud-full.qcow2 --public --container-format bare --disk-format qcow2 --property kernel_id=$KERNEL_ID --property ramdisk_id=$RAMDISK_ID rhel7-baremetal


# create baremetal nodes
openstack baremetal create ~/pod2-osp-d/stack-home/virtual-baremetal.yaml

# assign the ramdisk and kernel to the baremetal nodes TODO: replace with custom kernel and ramdisk for OCP
DEPLOY_KERNEL=$(openstack image show deploy-kernel -f value -c id)
DEPLOY_RAMDISK=$(openstack image show deploy-ramdisk -f value -c id)
for i in $(openstack baremetal node list --format value --column UUID);do
 openstack baremetal node set $i --driver-info deploy_kernel=$DEPLOY_KERNEL --driver-info deploy_ramdisk=$DEPLOY_RAMDISK
done

# next set all the baremetal nodes to manage, then provide with the following loop
for i in $(openstack baremetal node list --format value --column UUID);do
openstack baremetal node maintenance unset $i
#openstack baremetal node undeploy $i
openstack baremetal node manage $i
openstack baremetal node provide $i
done

## octavia LB
#openstack loadbalancer create --name lb1 --vip-subnet-id admin-subnet
#openstack loadbalancer listener create --name listener1 --protocol HTTP --protocol-port 80 lb1
#openstack loadbalancer pool create --name pool1 --lb-algorithm ROUND_ROBIN --listener listener1 --protocol HTTP
#openstack loadbalancer healthmonitor create --delay 5 --max-retries 4 --timeout 10 --type HTTP --url-path /healthcheck pool1
#openstack loadbalancer member create --subnet-id admin-subnet --address 192.168.99.3 --protocol-port 80 pool1
#openstack loadbalancer member create --subnet-id admin-subnet --address 192.168.99.10 --protocol-port 80 pool1

# After Designate integration
#neutron net-update openshift-net --dns_domain openshift.pod2.cloud.practice.redhat.com.
#
## current external addresses of controller0/1
#openstack subnet set openshift-subnet --dns-nameserver 10.12.134.55 --dns-nameserver 10.12.134.60


exit 0
#custom rhel5-guest based baremetal image
cd ~/images
export DIB_LOCAL_IMAGE=rhel-server-7.5-x86_64-kvm.qcow2
export REG_SAT_URL=http://pod2-satellite.cloud.practice.redhat.com
export REG_ORG=pod2
export REG_ACTIVATION_KEY=osp13-director-dev
export REG_METHOD=satellite
disk-image-create rhel7 baremetal -o rhel75-image

source ~/overcloudrc
KERNEL_ID=$(openstack image create \
--file rhel75-image.vmlinuz --public \
--container-format aki --disk-format aki \
-f value -c id rhel75-image.vmlinuz)
RAMDISK_ID=$(openstack image create \
--file rhel75-image.initrd --public \
--container-format ari --disk-format ari \
-f value -c id rhel75-image.initrd)
openstack image create \
--file rhel75-image.qcow2   --public \
--container-format bare \
--disk-format qcow2 \
--property kernel_id=$KERNEL_ID \
--property ramdisk_id=$RAMDISK_ID \
rhel75-baremetal