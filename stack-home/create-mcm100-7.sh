openstack server create MCM-100-7 \
--flavor AN-MCM \
--image an-controller-8.4.1.0-53.REL \
--port 2b519649-00d0-4674-a28d-7d5d59b5394a \
--port f2fdf32d-684b-4054-84eb-6bec8639dd8e \
--port 900313d4-bb6d-431c-820a-69824c6cf322 \
--config-drive True \
--user-data /home/affirmed/MCM-100-7-sriov-red-config.xml
