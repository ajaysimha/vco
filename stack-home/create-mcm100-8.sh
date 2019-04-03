openstack server create MCM-100-8 \
--flavor AN-MCM \
--image an-controller-8.4.1.0-53.REL \
--port 1fd7268f-2f90-4d15-b7d0-c304c40132e3 \
--port a5fdc902-ea95-40f3-9bc4-5ff2d836aad5 \
--port 543c2125-80e9-4e4a-85f3-b6976f0ae4dc \
--config-drive True \
--user-data /home/affirmed/MCM-100-8-sriov-red-config.xml
