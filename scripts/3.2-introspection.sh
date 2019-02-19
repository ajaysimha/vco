#!/usr/bin/env bash

# This script should be run as the stack user on the undercloud

# instackenv.json should contain all hosts in the deployment.
# In the OpenStack documentation, this file is called instack.json

# [ -f /home/stack/instackenv.json ] || echo "instackenv.json not found" && exit 1
source /home/stack/stackrc

#######################
# Import Ironic Nodes #
#######################
openstack overcloud node import /home/stack/pod2-osp-d/stack-home/instackenv.yaml

openstack overcloud node introspect --all-manageable --provide

