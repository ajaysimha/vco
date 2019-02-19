#!/bin/bash
source /home/stack/stackrc

#### global static variables
#
# The path to the stackrc file
#stackrc="/home/stack/stackrc"
#
# The path to overcloudrc file (this can also be named after your stack)
#overcloudrc="/home/stack/overcloudrc"
#
# The password set in mysql for the designate mysql user.
# This happens in the mysql grants for the databases created for designate
# See mysql databases: designate and designate_pool_manager
#designateMysqlPassword=designatedatabase
#
# The designate user created on the overcloud.
# This user becomes attached to the services project
#designateOvercloudPassword=designateovercloud

stackrc="/home/stack/stackrc"
overcloudrc="/home/stack/overcloudrc"
designateMysqlPassword=designatedatabase
designateOvercloudPassword=designateovercloud

echo "Static Variable Assignments"
echo "designateMysqlPassword = " $designateMysqlPassword
echo "designateOvercloudPassword = " $designateOvercloudPassword
echo ""
echo ""

#### overcloud dynamic variables
#

source $stackrc
controllerCtlPlaneIps=($(nova list | awk '/controller/ {print $12}' | sed s/ctlplane=//g))
computeCtlPlaneIps=($(nova list | awk '/compute/ {print $12}' | sed s/ctlplane=//g))
allCtlPlaneIps=($(nova list | awk '/ACTIVE/ {print $12}' | sed s/ctlplane=//g))

adminurlIP=$(openstack  port show -c fixed_ips internal_api_virtual_ip | awk -F\' '/ip_address/ {print $2}')
publicurlIP=$(openstack  port show -c fixed_ips public_virtual_ip | awk -F\' '/ip_address/ {print $2}')
internalurlIP=$(openstack  port show -c fixed_ips internal_api_virtual_ip | awk -F\' '/ip_address/ {print $2}')
rabbitHosts=($(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sudo grep -A3 rabbitmq_node_ips /etc/puppet/hieradata/all_nodes.json" | awk -F\" '/\./ {print $2}' | strings))
rabbitDefaultUser=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo grep -i rabbitmq::default_user /etc/puppet/hieradata/service_configs.json | awk -F\" '{print $4}')
rabbitDefaultPass=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo grep -i rabbitmq::default_pass /etc/puppet/hieradata/service_configs.json | awk -F\" '{print $4}')
redisVip=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo grep -i redis_vip /etc/puppet/hieradata/vip_data.json | awk -F\" '{print $4}')
redisPass=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo grep -i redis::masterauth /etc/puppet/hieradata/service_configs.json | awk -F\" '{print $4}')
mysqlPass=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo cat /var/lib/config-data/mysql/etc/puppet/hieradata/service_configs.json | grep mysql | grep root_password | awk -F": " '{print $2}' | awk -F"\"" '{print $2}')
neutronPass=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo grep -i neutron::db::mysql::password /etc/puppet/hieradata/service_configs.json | awk -F\" '{print $4}')
controllerIntapiIps=($(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sudo grep internalapi /etc/hosts" | awk '/controller/ {print $1}'))
controller0Intapi=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sudo grep \$(hostname -s).internalapi /etc/hosts" | awk '{print $1}')
controller1Intapi=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} "sudo grep \$(hostname -s).internalapi /etc/hosts" | awk '{print $1}')
controller0External=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sudo grep \$(hostname -s).external /etc/hosts" | awk '{print $1}')
controller1External=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} "sudo grep \$(hostname -s).external /etc/hosts" | awk '{print $1}')


source $overcloudrc
keystonePublicUrl=$(openstack endpoint list --service keystone --interface public -c URL -f value)
keystoneAdminUrl=$(openstack endpoint list --service keystone --interface admin -c URL -f value)
keystoneInternalUrl=$(openstack endpoint list --service keystone --interface internal -c URL -f value)

echo "Dynamic Variable Assignments"
echo "controllerCtlPlaneIps = " ${controllerCtlPlaneIps[*]}
echo "adminurlIP = " $adminurlIP
echo "publicurlIP = " $publicurlIP
echo "internalurlIP = " $internalurlIP
echo "rabbitHosts = " $rabbitHosts
echo "rabbitDefaultUser = " $rabbitDefaultUser
echo "rabbitDefaultPass = " $rabbitDefaultPass
echo "redisVip = " $redisVip
echo "redisPass = " $redisPass
echo "neutronPass = " $neutronPass
echo "controllerIntapiIps = " $controllerIntapiIps
echo "controller0Intapi = " $controller0Intapi
echo "controller1Intapi = " $controller1Intapi
echo "controller0External = " $controller0External
echo "controller1External = " $controller1External
echo "keystonePublicUrl = " $keystonePublicUrl
echo "keystoneAdminUrl = " $keystoneAdminUrl
echo "keystoneInternalUrl = " $keystoneInternalUrl
echo ""
echo ""


##Install designate rpms###
##Insert check for rpms already installed
source $stackrc
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo yum install -y openstack-designate-api openstack-designate-central openstack-designate-sink openstack-designate-pool-manager openstack-designate-mdns openstack-designate-common python-designate python-designateclient openstack-designate-agent openstack-designate-zone-manager" ; done
##Install designate rpms end###


##Create mysql database for designate###
##Insert check for database already existing
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"CREATE DATABASE designate\;\"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"GRANT ALL ON designate.* TO \'designate\'\@\'\%\' IDENTIFIED BY \'$designateMysqlPassword\'\;\"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"GRANT ALL ON designate.* TO \'designate\'\@\'localhost\' IDENTIFIED BY \'$designateMysqlPassword\'\;\"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"CREATE DATABASE designate_pool_manager\;\"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"GRANT ALL ON designate_pool_manager.* TO \'designate\'\@\'\%\' IDENTIFIED BY \'$designateMysqlPassword\'\;\"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"GRANT ALL ON designate_pool_manager.* TO \'designate\'\@\'localhost\' IDENTIFIED BY \'$designateMysqlPassword\'\;\"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo mysql -u root --password=$mysqlPass --exec=\"FLUSH PRIVILEGES\;\"
##mysql database ceation end###

##Create designate overcloud user and endpoint###
##Insert check for user and endpoint already existing
source $overcloudrc
openstack user create designate --password $designateOvercloudPassword --email designate@localhost
openstack role add --project service --user designate admin
openstack service create dns --name designate --description "Designate DNS Service"
openstack endpoint create --region regionOne designate public http://$publicurlIP:9001
openstack endpoint create --region regionOne designate admin http://$adminurlIP:9001
openstack endpoint create --region regionOne designate internal http://$internalurlIP:9001
##Create designate overcloud user and endpoint end###

##Create firewall rules###
##Insert check if firewall rules already exist
source $stackrc
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo iptables -I INPUT -p tcp -m multiport --dports 9001 -m comment --comment designate.incoming -j ACCEPT ; sudo iptables -I INPUT -p tcp -m multiport --dports 5354 -m comment --comment Designate.mdns.incoming -j ACCEPT ; sudo iptables -I INPUT -p tcp -m multiport --dports 953 -m comment --comment rndc.incoming.bind.only -j ACCEPT ; sudo iptables -I INPUT -p tcp -m multiport --dports 53 -m comment --comment DNS.tcp.incoming.bind.only -j ACCEPT ; sudo iptables -I INPUT -p udp -m multiport --dports 53 -m comment --comment DNS.udp.incoming.bind.only -j ACCEPT ;  sudo service iptables save " ; done
### Recommended by Joe A to not restart iptables
# for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo iptables -I INPUT -p tcp -m multiport --dports 9001 -m comment --comment designate.incoming -j ACCEPT ; sudo iptables -I INPUT -p tcp -m multiport --dports 5354 -m comment --comment Designate.mdns.incoming -j ACCEPT ; sudo iptables -I INPUT -p tcp -m multiport --dports 953 -m comment --comment rndc.incoming.bind.only -j ACCEPT ; sudo iptables -I INPUT -p tcp -m multiport --dports 53 -m comment --comment DNS.tcp.incoming.bind.only -j ACCEPT ; sudo iptables -I INPUT -p udp -m multiport --dports 53 -m comment --comment DNS.udp.incoming.bind.only -j ACCEPT ;  sudo service iptables save ; sudo service iptables restart" ; done
##Create firewall rules end###



##Configure designate.conf###
source $stackrc

#crudini --set /etc/designate/designate.conf storage:sqlalchemy connection mysql://designate:$designateMysqlPassword@$internalurlIP/designate
echo "crudini --set /etc/designate/designate.conf storage:sqlalchemy connection mysql://designate:$designateMysqlPassword@$internalurlIP/designate"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="storage:sqlalchemy"
crudiniValStore="connection"
crudiniSet="mysql://designate:$designateMysqlPassword@$internalurlIP/designate"
echo "Expecting $crudiniSet from mysql://designate:/$designateMysqlPassword@/$internalurlIP/designate"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf storage:sqlalchemy max_retries -1
echo "crudini --set /etc/designate/designate.conf storage:sqlalchemy max_retries -1"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="storage:sqlalchemy"
crudiniValStore="max_retries"
crudiniSet="-1"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /etc/designate/designate.conf pool_manager_cache:sqlalchemy connection mysql://designate:$designateMysqlPassword@$internalurlIP/designate_pool_manager
echo "crudini --set /etc/designate/designate.conf pool_manager_cache:sqlalchemy connection mysql://designate:$designateMysqlPassword@$internalurlIP/designate_pool_manager"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="pool_manager_cache:sqlalchemy"
crudiniValStore="connection"
crudiniSet="mysql://designate:$designateMysqlPassword@$internalurlIP/designate_pool_manager"
echo "Expecting $crudiniSet from mysql://designate:\$designateMysqlPassword@\$internalurlIP/designate_pool_manager"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf pool_manager_cache:sqlalchemy max_retries -1
echo "crudini --set /etc/designate/designate.conf pool_manager_cache:sqlalchemy max_retries -1"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="pool_manager_cache:sqlalchemy"
crudiniValStore="max_retries"
crudiniSet="-1"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken auth_type password
echo "crudini --set /etc/designate/designate.conf keystone_authtoken auth_type password"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="auth_type"
crudiniSet="password"
echo "Expecting $crudiniSet from \$keystoneInternalUrl"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken auth_url $keystoneInternalUrl
echo "crudini --set /etc/designate/designate.conf keystone_authtoken auth_url $keystoneInternalUrl"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="auth_url"
crudiniSet="$keystoneInternalUrl"
echo "Expecting $crudiniSet from \$keystoneInternalUrl"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken www_authenticate_url $keystoneInternalUrl
echo "crudini --set /etc/designate/designate.conf keystone_authtoken www_authenticate_url $keystoneInternalUrl"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="www_authenticate_url"
crudiniSet="$keystoneInternalUrl"
echo "Expecting $crudiniSet from \$keystoneInternalUrl"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken username designate
echo "crudini --set /etc/designate/designate.conf keystone_authtoken username designate"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="username"
crudiniSet="designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken password $designateOvercloudPassword
echo "crudini --set /etc/designate/designate.conf keystone_authtoken password $designateOvercloudPassword"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="password"
crudiniSet="$designateOvercloudPassword"
echo "Expecting $crudiniSet from \$designateOvercloudPassword"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken project_name service
echo "crudini --set /etc/designate/designate.conf keystone_authtoken project_name service"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="project_name"
crudiniSet="service"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken project_domain_name Default
echo "crudini --set /etc/designate/designate.conf keystone_authtoken project_domain_name Default"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="project_domain_name"
crudiniSet="Default"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf keystone_authtoken user_domain_name Default
echo "crudini --set /etc/designate/designate.conf keystone_authtoken user_domain_name Default"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="keystone_authtoken"
crudiniValStore="user_domain_name"
crudiniSet="Default"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_hosts ${rabbitHosts[0]}:5672,${rabbitHosts[1]}:5672,${rabbitHosts[2]}:5672
echo "crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_hosts ${rabbitHosts[0]}:5672,${rabbitHosts[1]}:5672,${rabbitHosts[2]}:5672"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="oslo_messaging_rabbit"
crudiniValStore="rabbit_hosts"
crudiniSet="${rabbitHosts[0]}:5672,${rabbitHosts[1]}:5672,${rabbitHosts[2]}:5672"
echo "Expecting $crudiniSet from \${rabbitHosts[0]}:5672,\${rabbitHosts[1]}:5672,\${rabbitHosts[2]}:5672"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_ha_queues True
echo "crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_ha_queues True"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="oslo_messaging_rabbit"
crudiniValStore="rabbit_ha_queues"
crudiniSet="True"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_userid $rabbitDefaultUser
echo "crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_userid $rabbitDefaultUser"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="oslo_messaging_rabbit"
crudiniValStore="rabbit_userid"
crudiniSet="$rabbitDefaultUser"
echo "Expecting $crudiniSet from \$rabbitDefaultUser"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_password $rabbitDefaultPass
echo "crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_password $rabbitDefaultPass"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="oslo_messaging_rabbit"
crudiniValStore="rabbit_password"
crudiniSet="$rabbitDefaultPass"
echo "Expecting $crudiniSet from \$rabbitDefaultPass"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_virtual_host /
echo "crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_virtual_host /"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="oslo_messaging_rabbit"
crudiniValStore="rabbit_virtual_host"
crudiniSet="/"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

##crudini --set /etc/designate/designate.conf service:api enable_host_header true
#echo "crudini --set /etc/designate/designate.conf service:api enable_host_header true"
#crudiniFile="/etc/designate/designate.conf"
#crudiniHeading="service:api"
#crudiniValStore="enable_host_header"
#crudiniSet="true"
#echo "Expecting $crudiniSet from static"
#for i in ${controllerCtlPlaneIps[@]}
#  do
#    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
#    echo "Got $crudiniGet from crudini on $i"
#    if [ "$crudiniGet" == "$crudiniSet" ]
#      then
#        echo  "Value of $crudiniSet set correctly on $i"
#      else
#       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
#       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
#       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
#       if [ "$crudiniGet" == "$crudiniSet" ]
#         then
#           echo  "Value of $crudiniSet set correctly on $i"
#         else
#           echo "Failed to set $crudiniSet on $i.  Exiting"
#           exit
#       fi
#    fi
#done
#echo ""


#ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@10.9.68.77 "sudo grep ^notification_driver /etc/designate/designate.conf" | wc -l
for i in ${controllerCtlPlaneIps[@]}
  do
    lineCount=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo grep ^notification_driver /etc/designate/designate.conf" | wc -l)
    if [ "$lineCount" -ge "2" ]
      then
        echo "Skipping $i, multiple entries for notification_driver already detected"
      else
        #crudini --set /etc/designate/designate.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
        echo "crudini --set /etc/designate/designate.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier"
        crudiniFile="/etc/designate/designate.conf"
        crudiniHeading="DEFAULT"
        crudiniValStore="notification_driver"
        crudiniSet="nova.openstack.common.notifier.rpc_notifier"
        crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
        echo "Got $crudiniGet from crudini on $i"
        if [ "$crudiniGet" == "$crudiniSet" ]
          then
            echo  "Value of $crudiniSet set correctly on $i"
          else
            echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
            crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
            if [ "$crudiniGet" == "$crudiniSet" ]
              then
                echo  "Value of $crudiniSet set correctly on $i"
              else
                echo "Failed to set $crudiniSet on $i.  Exiting"
                exit
            fi
        fi
        #crudini --set /etc/designate/designate.conf DEFAULT notification_driver messaging
        echo "crudini --set /etc/designate/designate.conf DEFAULT notification_driver2 messaging"
        crudiniFile="/etc/designate/designate.conf"
        crudiniHeading="DEFAULT"
        crudiniValStore="notification_driver2"
        crudiniSet="messaging"
        crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
        echo "Got $crudiniGet from crudini on $i"
        if [ "$crudiniGet" == "$crudiniSet" ]
          then        
            echo  "Value of $crudiniSet set correctly on $i"
          else
            echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
            crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
            if [ "$crudiniGet" == "$crudiniSet" ]
              then
                echo  "Value of $crudiniSet set correctly on $i"
              else
                echo "Failed to set $crudiniSet on $i.  Exiting"
                exit
            fi
        fi
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo sed -i s/notification_driver2/notification_driver/ /etc/designate/designate.conf
    fi
done
echo "" 

#crudini --set /etc/designate/designate.conf DEFAULT notification_topics notifications_designate
echo "crudini --set /etc/designate/designate.conf DEFAULT notification_topics notifications_designate"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notification_topics"
crudiniSet="notifications_designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /etc/designate/designate.conf service:api api_host ${controllerIntapiIps[*]}
echo "crudini --set /etc/designate/designate.conf service:api api_host \${controllerIntapiIps[*]}"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="api_host"
indexCount=0
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniSet=${controllerIntapiIps[$indexCount]}
    echo "Expecting $crudiniSet from \${controllerIntapiIps[*]}"
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
    ((indexCount++))
done
echo ""

#crudini --set /etc/designate/designate.conf service:api api_port 9001
echo "crudini --set /etc/designate/designate.conf service:api api_port 9001"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="api_port"
crudiniSet="9001"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf service:api auth_strategy keystone
echo "crudini --set /etc/designate/designate.conf service:api auth_strategy keystone"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="auth_strategy"
crudiniSet="keystone"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf service:api enable_api_v1 True
echo "crudini --set /etc/designate/designate.conf service:api enable_api_v1 True"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="enable_api_v1"
crudiniSet="True"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf service:api enabled_extensions_v1 '"diagnostics, quotas, reports, sync, touch"'
echo "crudini --set /etc/designate/designate.conf service:api enabled_extensions_v1 '\"diagnostics, quotas, reports, sync, touch\"'"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="enabled_extensions_v1"
crudiniSet="diagnostics, quotas, reports, sync, touch"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore \"$crudiniSet\"
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf coordination backend_url redis://:$redisPass@$redisVip:6379/
echo "crudini --set /etc/designate/designate.conf coordination backend_url redis://:$redisPass@$redisVip:6379/"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="coordination"
crudiniValStore="backend_url"
crudiniSet="redis://:$redisPass@$redisVip:6379/"
echo "Expecting $crudiniSet from \$redisPass@\$redisVip"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf service:api enable_api_v2 True
echo "crudini --set /etc/designate/designate.conf service:api enable_api_v2 True"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="enable_api_v2"
crudiniSet="True"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do 
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf service:api enabled_extensions_v2 '"quotas, reports"'
echo "crudini --set /etc/designate/designate.conf service:api enabled_extensions_v2 \"quotas, reports\""
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:api"
crudiniValStore="enabled_extensions_v2"
crudiniSet="quotas, reports"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore \"$crudiniSet\"
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /etc/designate/designate.conf service:sink enabled_notification_handlers '"nova_fixed, neutron_floatingip"'
echo "crudini --set /etc/designate/designate.conf service:sink enabled_notification_handlers \"nova_fixed, neutron_floatingip\""
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="service:sink"
crudiniValStore="enabled_notification_handlers"
crudiniSet="nova_fixed, neutron_floatingip"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore \"$crudiniSet\"
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:nova_fixed notification_topics notifications_designate
echo "crudini --set /etc/designate/designate.conf handler:nova_fixed notification_topics notifications_designate"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:nova_fixed"
crudiniValStore="notification_topics"
crudiniSet="notifications_designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:nova_fixed control_exchange nova
echo "crudini --set /etc/designate/designate.conf handler:nova_fixed control_exchange nova"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:nova_fixed"
crudiniValStore="control_exchange"
crudiniSet="nova"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i" 
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting" 
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:nova_fixed format "'%(display_name)s.%(zone)s'"
echo "crudini --set /etc/designate/designate.conf handler:nova_fixed format \"'%(display_name)s.%(zone)s'\""
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:nova_fixed"
crudiniValStore="format"
crudiniSet="'%(display_name)s.%(zone)s'"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore \"$crudiniSet\"
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:nova_fixed formatv4 "'%(display_name)s.%(zone)s'"
echo "crudini --set /etc/designate/designate.conf handler:nova_fixed formatv4 \"'%(display_name)s.%(zone)s'\""
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:nova_fixed"
crudiniValStore="formatv4"
crudiniSet="'%(display_name)s.%(zone)s'"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore \"$crudiniSet\"
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:neutron_floatingip notification_topics notifications_designate
echo "crudini --set /etc/designate/designate.conf handler:neutron_floatingip notification_topics notifications_designate"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:neutron_floatingip"
crudiniValStore="notification_topics"
crudiniSet="notifications_designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:neutron_floatingip control_exchange neutron
echo "crudini --set /etc/designate/designate.conf handler:neutron_floatingip control_exchange neutron"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:neutron_floatingip"
crudiniValStore="control_exchange"
crudiniSet="neutron"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do 
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /etc/designate/designate.conf handler:neutron_floatingip format "'%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.%(domain)s'"
echo "crudini --set /etc/designate/designate.conf handler:neutron_floatingip format \"'%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.%(domain)s'\""
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:neutron_floatingip"
crudiniValStore="format"
crudiniSet="'%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.%(domain)s'"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore \"$crudiniSet\"
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

##configure designate.conf end###

##Sync database and start designate###
##Need to break sync into separate command and add check to see if it has been done before
source $stackrc
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sudo designate-manage database sync ; sudo designate-manage pool-manager-cache sync"
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo systemctl enable --now designate-central designate-api designate-mdns designate-pool-manager designate-zone-manager" ; done
##

##generate bind.conf###
source $stackrc
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo yum -y install bind bind-utils; done
cat << EOF > bind.conf
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//
// See the BIND Administrator's Reference Manual (ARM) for details about the
// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

include "/etc/rndc.key";
acl "rndc-users" {
   CONTROLLERINTIPS
};
controls {
       inet 127.0.0.1 allow { localhost; } keys { "rndc-key"; };
       inet LOCALINTIP allow {"rndc-users";} keys {"rndc-key";};
};
options {
       allow-new-zones yes;
       request-ixfr no;
       allow-query { any; };
       recursion yes;
       forwarders {
            10.12.32.1;
                  };
listen-on port 53 { 127.0.0.1; LOCALEXTIP; CTLPLANEIP; LOCALINTIP; };
listen-on-v6 port 53 { ::1; };
directory "/var/named";
dump-file "/var/named/data/cache_dump.db";
statistics-file "/var/named/data/named_stats.txt";
memstatistics-file "/var/named/data/named_mem_stats.txt";

/*
- If you are building a RECURSIVE (caching) DNS server, you need to enable
- If your recursive DNS server has a public IP address, you MUST enable access
  control to limit queries to your legitimate users. Failing to do so will
  cause your server to become part of large scale DNS amplification
  attacks. Implementing BCP38 within your network would greatly
  reduce such attack surface
*/

dnssec-enable yes;
dnssec-validation yes;

/* Path to ISC DLV key */
bindkeys-file "/etc/named.iscdlv.key";

managed-keys-directory "/var/named/dynamic";

pid-file "/run/named/named.pid";
session-keyfile "/run/named/session.key";
};

logging {
       channel default_debug {
               file "data/named.run";
               severity dynamic;
       };
};

zone "." IN {
type hint;
file "named.ca";
};
EOF

for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no bind.conf heat-admin@$i:~/ ; done
for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sed -i s/CONTROLLERINTIPS/${controllerIntapiIps[0]}\;${controllerIntapiIps[1]}\;${controllerIntapiIps[2]}\;/ ~/bind.conf" ; done
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sed -i s/LOCALINTIP/$controller0Intapi/ ~/bind.conf"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sed -i s/LOCALEXTIP/$controller0External/ ~/bind.conf"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sed -i s/CTLPLANEIP/${controllerCtlPlaneIps[0]}/ ~/bind.conf"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} "sed -i s/LOCALINTIP/$controller1Intapi/ ~/bind.conf"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} "sed -i s/LOCALEXTIP/$controller1External/ ~/bind.conf"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} "sed -i s/CTLPLANEIP/${controllerCtlPlaneIps[1]}/ ~/bind.conf"
for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo cp /home/heat-admin/bind.conf /etc/named.conf ; done
##generate bind.conf end###

##generate rndc keys###
source $stackrc
for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo rndc-confgen -a ; done

cat << EOF > rndc.conf
include "/etc/rndc.key";
options {
       default-key "rndc-key";
       default-server LOCALINTIP;
       default-port 953;
};
EOF

for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no rndc.conf heat-admin@$i:~/ ; done
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} "sed -i s/LOCALINTIP/$controller0Intapi/ ~/rndc.conf"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} "sed -i s/LOCALINTIP/$controller1Intapi/ ~/rndc.conf"
for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo cp /home/heat-admin/rndc.conf /etc/rndc.conf ; done
for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo setsebool -P named_write_master_zones on ; sudo chmod g+w /var/named ; sudo chown named:named /etc/rndc.conf ; sudo chown named:named /etc/rndc.key ; sudo chmod 600 /etc/rndc.key " ; done
for i in ${controllerCtlPlaneIps[0]} ${controllerCtlPlaneIps[1]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo systemctl enable named ; sudo systemctl start named" ; done
##generate rndc keys end###

##generate bundled rndc keys and conf###
source $stackrc
cat << EOF > bundled_rndc.key
key "rndc-key-controller-0" {
algorithm hmac-md5;
secret "CONTROLLER0KEY";
};
key "rndc-key-controller-1" {
algorithm hmac-md5;
secret "CONTROLLER1KEY";
};
EOF



controller0Secret=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo grep secret /etc/rndc.key | awk -F\" '{print $2}')
controller1Secret=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[1]} sudo grep secret /etc/rndc.key | awk -F\" '{print $2}')
sed -i "s|CONTROLLER0KEY|$controller0Secret|g" ~/bundled_rndc.key
sed -i "s|CONTROLLER1KEY|$controller1Secret|g" ~/bundled_rndc.key
for i in ${controllerCtlPlaneIps[@]} ; do scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no bundled_rndc.key heat-admin@$i:~/ ; done
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo cp /home/heat-admin/bundled_rndc.key /etc/designate/bundled_rndc.key" ; done

cat << EOF > bundled_rndc.conf
include "/etc/designate/bundled_rndc.key";
server LOCALINTIP0 {
       key "rndc-key-controller-0";
       port 953;
};
server LOCALINTIP1 {
       key "rndc-key-controller-1";
       port 953;
};
EOF

sed -i s/LOCALINTIP0/$controller0Intapi/ ~/bundled_rndc.conf
sed -i s/LOCALINTIP1/$controller1Intapi/ ~/bundled_rndc.conf
for i in ${controllerCtlPlaneIps[@]} ; do scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no bundled_rndc.conf heat-admin@$i:~/ ; done
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo cp /home/heat-admin/bundled_rndc.conf /etc/designate/rndc.conf" ; done
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo chmod 644 /etc/designate/bundled_rndc.key ; sudo chmod 640 /etc/designate/rndc.conf ; sudo chown -R root:designate /etc/designate/" ; done
##generate bundled rndc keys and conf end###

##generate pools.yaml###
source $stackrc
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo designate-manage pool generate_file 

cat << EOF > pools.yaml
- also_notifies: []
  attributes: {}
  description: Default Bind pool
  id: 794ccc2c-d751-44fe-b57f-8894c9f5c842
  name: custom_pool
  nameservers:
  - host: LOCALINTIP0
    port: 53
  - host: LOCALINTIP1
    port: 53
  ns_records:
  - hostname: ns.overcloud-controller-0.localdomain.
    priority: 1
  - hostname: ns.overcloud-controller-1.localdomain.
    priority: 2
  targets:
  - masters:
    - host: LOCALINTIP0
      port: 5354
    - host: LOCALINTIP1
      port: 5354
    options:
      host: LOCALINTIP0
      port: 53
      rndc_config_file: /etc/designate/rndc.conf
      rndc_host: LOCALINTIP0
      rndc_key_file: /etc/designate/bundled_rndc.key
      rndc_port: '953'
    type: bind9
  - masters:
    - host: LOCALINTIP0
      port: 5354
    - host: LOCALINTIP1
      port: 5354
    options:
      host: LOCALINTIP1
      port: 53
      rndc_config_file: /etc/designate/rndc.conf
      rndc_host: LOCALINTIP1
      rndc_key_file: /etc/designate/bundled_rndc.key
      rndc_port: '953'
    type: bind9
EOF

sed -i s/LOCALINTIP0/${controllerIntapiIps[0]}/g ~/pools.yaml
sed -i s/LOCALINTIP1/${controllerIntapiIps[1]}/g ~/pools.yaml
sed -i s/LOCALINTIP2/${controllerIntapiIps[2]}/g ~/pools.yaml
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ~/pools.yaml heat-admin@${controllerCtlPlaneIps[0]}:~/ 
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo cp /home/heat-admin/pools.yaml /etc/designate/pools.yaml
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo designate-manage pool update --delete true
##generate pools.yaml end###


##configure nova.conf on controllers
source $stackrc

#crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notification_topics notifications,notifications_designate
echo "crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notification_topics notifications,notifications_designate"
crudiniFile="/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notification_topics"
crudiniSet="notifications,notifications_designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

 # we need this on controllers too as they run the nova-compute service for ironic, otherwise it could remain just for computes

for i in ${controllerCtlPlaneIps[@]}
  do
    lineCount=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo grep ^notification_driver /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf" | wc -l)
    if [ "$lineCount" -ge "2" ]
      then
        echo "Skipping $i, multiple entries for notification_driver already detected"
      else
        echo "crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rabbit_notifier,ceilometer.compute.nova_notifier"
        crudiniFile="/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf"
        crudiniHeading="DEFAULT"
        crudiniValStore="notification_driver"
        crudiniSet="nova.openstack.common.notifier.rabbit_notifier,ceilometer.compute.nova_notifier"
        crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
        echo "Got $crudiniGet from crudini on $i"
        if [ "$crudiniGet" == "$crudiniSet" ]
          then
            echo  "Value of $crudiniSet set correctly on $i"
          else
            echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
            crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
            if [ "$crudiniGet" == "$crudiniSet" ]
              then
                echo  "Value of $crudiniSet set correctly on $i"
              else
                echo "Failed to set $crudiniSet on $i.  Exiting"
                exit
            fi
        fi
        #crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notification_driver messaging
        echo "crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notification_driver2 messaging"
        crudiniFile="/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf"
        crudiniHeading="DEFAULT"
        crudiniValStore="notification_driver2"
        crudiniSet="messaging"
        crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
        echo "Got $crudiniGet from crudini on $i"
        if [ "$crudiniGet" == "$crudiniSet" ]
          then
            echo  "Value of $crudiniSet set correctly on $i"
          else
            echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
            crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
            if [ "$crudiniGet" == "$crudiniSet" ]
              then
                echo  "Value of $crudiniSet set correctly on $i"
              else
                echo "Failed to set $crudiniSet on $i.  Exiting"
                exit
            fi
        fi
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo sed -i s/notification_driver2/notification_driver/ /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
echo "crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state"
crudiniFile="/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notify_on_state_change"
crudiniSet="vm_and_task_state"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
echo "crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT instance_usage_audit_period hour"
crudiniFile="/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="instance_usage_audit_period"
crudiniSet="hour"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT instance_usage_audit true
echo "crudini --set /var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf DEFAULT instance_usage_audit true"
crudiniFile="/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="instance_usage_audit"
crudiniSet="true"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

##configure nova.conf on controllers end###

##configure nova.conf on computes

for i in ${computeCtlPlaneIps[@]}
  do
    lineCount=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo grep ^notification_driver /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf" | wc -l)
    if [ "$lineCount" -ge "2" ]
      then
        echo "Skipping $i, multiple entries for notification_driver already detected"
      else
        echo "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rabbit_notifier,ceilometer.compute.nova_notifier"
        crudiniFile="/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
        crudiniHeading="DEFAULT"
        crudiniValStore="notification_driver"
        crudiniSet="nova.openstack.common.notifier.rabbit_notifier,ceilometer.compute.nova_notifier"
        crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
        echo "Got $crudiniGet from crudini on $i"
        if [ "$crudiniGet" == "$crudiniSet" ]
          then
            echo  "Value of $crudiniSet set correctly on $i"
          else
            echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
            crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
            if [ "$crudiniGet" == "$crudiniSet" ]
              then
                echo  "Value of $crudiniSet set correctly on $i"
              else
                echo "Failed to set $crudiniSet on $i.  Exiting"
                exit
            fi
        fi
        #crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notification_driver messaging
        echo "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notification_driver2 messaging"
        crudiniFile="/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
        crudiniHeading="DEFAULT"
        crudiniValStore="notification_driver2"
        crudiniSet="messaging"
        crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
        echo "Got $crudiniGet from crudini on $i"
        if [ "$crudiniGet" == "$crudiniSet" ]
          then
            echo  "Value of $crudiniSet set correctly on $i"
          else
            echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
            ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
            crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
            if [ "$crudiniGet" == "$crudiniSet" ]
              then
                echo  "Value of $crudiniSet set correctly on $i"
              else
                echo "Failed to set $crudiniSet on $i.  Exiting"
                exit
            fi
        fi
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo sed -i s/notification_driver2/notification_driver/ /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notification_topics notifications,notifications_designate
echo "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notification_topics notifications,notifications_designate"
crudiniFile="/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notification_topics"
crudiniSet="notifications,notifications_designate"
echo "Expecting $crudiniSet from static"
for i in ${computeCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
echo "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state"
crudiniFile="/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notify_on_state_change"
crudiniSet="vm_and_task_state"
echo "Expecting $crudiniSet from static"
for i in ${computeCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
echo "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT instance_usage_audit_period hour"
crudiniFile="/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="instance_usage_audit_period"
crudiniSet="hour"
echo "Expecting $crudiniSet from static"
for i in ${computeCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT instance_usage_audit true
echo "crudini --set /var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf DEFAULT instance_usage_audit true"
crudiniFile="/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf"
crudiniHeading="DEFAULT"
crudiniValStore="instance_usage_audit"
crudiniSet="true"
echo "Expecting $crudiniSet from static"
for i in ${computeCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


##configure nova.conf on computes end##

##configure neutron.conf###

source $stackrc

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notification_driver"
crudiniSet="neutron.openstack.common.notifier.rpc_notifier"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT notification_topics notifications,notifications_designate
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT notification_topics notifications,notifications_designate"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="DEFAULT"
crudiniValStore="notification_topics"
crudiniSet="notifications,notifications_designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT external_dns_driver designate 
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT external_dns_driver designate"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="DEFAULT"
crudiniValStore="external_dns_driver"
crudiniSet="designate"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers qos,port_security,dns_domain_ports
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers qos,port_security,dns_domain_ports"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini"
crudiniHeading="ml2"
crudiniValStore="extension_drivers"
crudiniSet="qos,port_security,dns_domain_ports"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate url http://$publicurlIP:9001/v2
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate url http://$publicurlIP:9001/v2"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="url"
crudiniSet="http://$publicurlIP:9001/v2"
echo "Expecting $crudiniSet from http://\$publicurlIP:9001/v2"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate auth_type password
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate auth_type password"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="auth_type"
crudiniSet="password"
echo "Expecting $crudiniSet from \$keystoneAdminUrl"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate auth_url $keystoneInternalUrl
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate auth_url $keystoneInternalUrl"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="auth_url"
crudiniSet="$keystoneInternalUrl"
echo "Expecting $crudiniSet from \$keystoneInternalUrl"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate username neutron
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate username neutron"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="username"
crudiniSet="neutron"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate password $neutronPass
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate password $neutronPass"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="password"
crudiniSet="$neutronPass"
echo "Expecting $crudiniSet from \$neutronPass"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate project_name service
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate project_name service"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="project_name"
crudiniSet="service"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate project_domain_name Default
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate project_domain_name Default"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="project_domain_name"
crudiniSet="Default"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate user_domain_name Default
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate user_domain_name Default"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="user_domain_name"
crudiniSet="Default"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate allow_reverse_dns_lookup true
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate allow_reverse_dns_lookup true"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="allow_reverse_dns_lookup"
crudiniSet="true"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate auth_uri $keystoneInternalUrl
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf designate auth_uri $keystoneInternalUrl"
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="designate"
crudiniValStore="auth_uri"
crudiniSet="$keystoneInternalUrl"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

#crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT dns_domain openshift.pod2.cloud.practice.redhat.com.
echo "crudini --set /var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf DEFAULT dns_domain openshift.pod2.cloud.practice.redhat.com."
crudiniFile="/var/lib/config-data/puppet-generated/neutron/etc/neutron/neutron.conf"
crudiniHeading="DEFAULT"
crudiniValStore="dns_domain"
crudiniSet="openshift.pod2.cloud.practice.redhat.com."
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""

for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo docker restart neutron_api neutron_ovs_agent neutron_metadata_agent neutron_l3_agent neutron_dhcp" ; done

for i in ${computeCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo docker restart nova_compute" ; done

# were running baremetal on controllers
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo docker restart nova_compute" ; done

##configure neutron.conf end###

##configure haproxy.conf###
source $stackrc
cat << EOF > proxy.conf
listen designate
 bind PUBLICVIP:9001 transparent
 bind INTERNALVIP:9001 transparent
 mode http
 http-request set-header X-Forwarded-Proto https if { ssl_fc }
 http-request set-header X-Forwarded-Proto http if !{ ssl_fc }
 server overcloud-controller-0.internalapi LOCALINTIP0:9001 check fall 5 inter 2000 rise 2
 server overcloud-controller-1.internalapi LOCALINTIP1:9001 check fall 5 inter 2000 rise 2
 server overcloud-controller-2.internalapi LOCALINTIP2:9001 check fall 5 inter 2000 rise 2
EOF

sed -i s/LOCALINTIP0/${controllerIntapiIps[0]}/g ~/proxy.conf
sed -i s/LOCALINTIP1/${controllerIntapiIps[1]}/g ~/proxy.conf
sed -i s/LOCALINTIP2/${controllerIntapiIps[2]}/g ~/proxy.conf
sed -i s/PUBLICVIP/$publicurlIP/g ~/proxy.conf
sed -i s/INTERNALVIP/$internalurlIP/g ~/proxy.conf
for i in ${controllerCtlPlaneIps[@]} ; do scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ~/proxy.conf heat-admin@$i:~/ ; done
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo "cat /var/lib/config-data/puppet-generated/haproxy/etc/haproxy/haproxy.cfg /home/heat-admin/proxy.conf > /home/heat-admin/haproxy.conf" ; done
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo cp /home/heat-admin/haproxy.conf /var/lib/config-data/puppet-generated/haproxy/etc/haproxy/haproxy.cfg ; done
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@${controllerCtlPlaneIps[0]} sudo pcs resource restart haproxy-bundle
##configure haproxy.conf end###


for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo systemctl enable named ; sudo systemctl restart named" ; done

##configure caching nameserver end###

# now we need to create the openshift.pod2 zone
source ~/openshiftrc
openstack zone create openshift.pod2.cloud.practice.redhat.com. --email broskos@redhat.com

#then we take the resulting zone file and push it to designate.conf

zoneid=$(openstack zone list -f value -c id)

#crudini --set /etc/designate/designate.conf handler:nova_fixed zone_id $zoneid
echo "crudini --set /etc/designate/designate.conf handler:nova_fixed zone_id $zoneid"
crudiniFile="/etc/designate/designate.conf"
crudiniHeading="handler:nova_fixed"
crudiniValStore="zone_id"
crudiniSet="$zoneid"
echo "Expecting $crudiniSet from static"
for i in ${controllerCtlPlaneIps[@]}
  do
    crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
    echo "Got $crudiniGet from crudini on $i"
    if [ "$crudiniGet" == "$crudiniSet" ]
      then
        echo  "Value of $crudiniSet set correctly on $i"
      else
       echo "Value of $crudiniGet not set to $crudiniSet on $i.  Setting Value..."
       ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --set $crudiniFile $crudiniHeading $crudiniValStore $crudiniSet
       crudiniGet=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i sudo crudini --get $crudiniFile $crudiniHeading $crudiniValStore)
       if [ "$crudiniGet" == "$crudiniSet" ]
         then
           echo  "Value of $crudiniSet set correctly on $i"
         else
           echo "Failed to set $crudiniSet on $i.  Exiting"
           exit
       fi
    fi
done
echo ""


# restart designate
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo systemctl restart designate-central designate-api designate-mdns designate-pool-manager designate-zone-manager designate-sink " ; done

#disable em2 - this is a lab specific configuration requirement related to asymetric routing - we need to disable the 10.12.32.0 network on these hosts so that the main dns server can
# reach them from 10.12.32.0 via 10.12.134.0
for i in ${controllerCtlPlaneIps[@]} ; do ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no heat-admin@$i "sudo nmcli con mod 'System em2' connection.autoconnect no ; sudo nmcli con down 'System em2' " ; done

