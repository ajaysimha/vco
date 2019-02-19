#!/usr/bin/env bash

yum install -y rhel-guest-image-7 libguestfs-tools libvirt qemu-kvm \
   virt-manager virt-install xorg-x11-apps xauth virt-viewer libguestfs-xfs python-virtualbmc python-setuptools
systemctl enable libvirtd && systemctl start libvirtd

cd /vms

#create emtpy disks for root disks
qemu-img create -f qcow2 ceph1.qcow2 50G
qemu-img create -f qcow2 ceph2.qcow2 50G
qemu-img create -f qcow2 ceph3.qcow2 50G
qemu-img create -f qcow2 baremetal1.qcow2 100G
qemu-img create -f qcow2 baremetal2.qcow2 100G
qemu-img create -f qcow2 baremetal3.qcow2 100G

#create vlans and bridges on em1
nmcli con mod em1 connection.autoconnect yes

nmcli con add type vlan ifname vlan3134 dev em1 id 3134
nmcli con add ifname br-internalapi type bridge con-name br-internalapi
nmcli con mod br-internalapi ipv4.method disabled
nmcli con mod vlan-vlan3134 connection.slave-type bridge connection.master br-internalapi
nmcli con down vlan-vlan3134
nmcli con up br-internalapi

nmcli con add type vlan ifname vlan3234 dev em1 id 3234
nmcli con add ifname br-storage type bridge con-name br-storage
nmcli con mod br-storage ipv4.method disabled
nmcli con mod vlan-vlan3234 connection.slave-type bridge connection.master br-storage
nmcli con down vlan-vlan3234
nmcli con up br-storage

nmcli con add type vlan ifname vlan3334 dev em1 id 3334
nmcli con add ifname br-storagemgmt type bridge con-name br-storagemgmt
nmcli con mod br-storagemgmt ipv4.method disabled
nmcli con mod vlan-vlan3334 connection.slave-type bridge connection.master br-storagemgmt
nmcli con down vlan-vlan3334
nmcli con up br-storagemgmt

nmcli con add type vlan ifname vlan1134 dev em1 id 1134
nmcli con add ifname br-baremetal type bridge con-name br-baremetal
nmcli con mod br-baremetal ipv4.method disabled
nmcli con mod vlan-vlan1134 connection.slave-type bridge connection.master br-baremetal
nmcli con down vlan-vlan1134
nmcli con up br-baremetal

nmcli con add ifname br-provision type bridge con-name br-provision
nmcli con mod em1 connection.slave-type bridge connection.master br-provision
nmcli con down em1
nmcli con up br-provision

systemctl restart network

virt-install --ram 8000 --vcpus 4 --os-variant rhel7 \
    --disk path=/vms/ceph1.qcow2,device=disk,bus=virtio,format=qcow2 \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75a5b0ec0926e,device=disk,bus=sata,format=raw \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75a660f681271,device=disk,bus=sata,format=raw \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75a741045efc7,device=disk,bus=sata,format=raw \
    --import --noautoconsole --vnc \
    --bridge br-provision \
    --bridge br-storage \
    --bridge br-storagemgmt \
    --name ceph1

virt-install --ram 8000 --vcpus 4 --os-variant rhel7 \
    --disk path=/vms/ceph2.qcow2,device=disk,bus=virtio,format=qcow2 \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75a8010f9a1e2,device=disk,bus=sata,format=raw \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75a8c11b7906c,device=disk,bus=sata,format=raw \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75a9a128bec5c,device=disk,bus=sata,format=raw \
    --import --noautoconsole --vnc \
    --bridge br-provision \
    --bridge br-storage \
    --bridge br-storagemgmt \
    --name ceph2

virt-install --ram 8000 --vcpus 4 --os-variant rhel7 \
    --disk path=/vms/ceph3.qcow2,device=disk,bus=virtio,format=qcow2 \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75aa6133fdc6b,device=disk,bus=sata,format=raw \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75ab314026a40,device=disk,bus=sata,format=raw \
    --disk path=/dev/disk/by-id/scsi-36b083fe0c10790001bd75abe14ae1076,device=disk,bus=sata,format=raw \
    --import --noautoconsole --vnc \
    --bridge br-provision \
    --bridge br-storage \
    --bridge br-storagemgmt \
    --name ceph3

virt-install --ram 8000 --vcpus 4 --os-variant rhel7 \
    --disk path=/vms/baremetal1.qcow2,device=disk,bus=virtio,format=qcow2 \
    --import --noautoconsole --vnc \
    --bridge br-baremetal \
    --name baremetal1

virt-install --ram 8000 --vcpus 4 --os-variant rhel7 \
    --disk path=/vms/baremetal2.qcow2,device=disk,bus=virtio,format=qcow2 \
    --import --noautoconsole --vnc \
    --bridge br-baremetal \
    --name baremetal2

virt-install --ram 8000 --vcpus 4 --os-variant rhel7 \
    --disk path=/vms/baremetal3.qcow2,device=disk,bus=virtio,format=qcow2 \
    --import --noautoconsole --vnc \
    --bridge br-baremetal \
    --name baremetal3

counter=6030
for vm in ceph1 ceph2 ceph3 baremetal1 baremetal2 baremetal3;do
counter=$((counter+1))
vbmc add $vm --port $counter --username admin --password redhat
vbmc start $vm
done;

cat << EOF > /etc/rc.d/rc.vbmc
for vm in ceph1 ceph2 ceph3 baremetal1 baremetal2;do
vbmc start \$vm
done;
EOF
chmod +x /etc/rc.d/rc.vbmc

#create virtual ceph inventory file
counter=6030
echo '---' > /root/virtual-ceph.yaml
echo 'nodes:' >> /root/virtual-ceph.yaml
for vm in ceph1 ceph2 ceph3;do
counter=$((counter+1))
mac=$(virsh domiflist $vm |grep provision|awk '{print $5}')
cat << EOF >> /root/virtual-ceph.yaml
- mac:
  - $mac
  name: $vm
  cpu: '4'
  memory: '6144'
  disk: '40'
  arch: x86_64
  pm_type: ipmi
  pm_port: $counter
  pm_user: admin
  pm_password: redhat
  pm_addr: 10.12.32.26
  capabilities: profile:ceph-storage,boot_option:local
EOF
done

#create virtual baremetal inventory file
echo '---' > /root/virtual-baremetal.yaml
echo 'nodes:' >> /root/virtual-baremetal.yaml
for vm in baremetal1 baremetal2 baremetal3 ;do
counter=$((counter+1))
mac=$(virsh domiflist $vm |grep baremetal|awk '{print $5}')
cat << EOF >> /root/virtual-baremetal.yaml
- name: $vm
  driver: pxe_ipmitool
  driver_info:
    ipmi_address: 10.12.32.26
    ipmi_username: admin
    ipmi_password: redhat
    ipmi_port: $counter
  properties:
    cpus: 4
    cpu_arch: x86_64
    memory_mb: 6144
    local_gb: 40
    root_device:
        name: /dev/vda1
  ports:
    - address: $mac
EOF
done

for i in $(seq 6031 $counter);do
firewall-cmd --add-port $i/udp
firewall-cmd --add-port $i/udp --permanent
done