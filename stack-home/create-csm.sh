openstack server create CSM-100-1 \
--flavor AN-CSM \
--image an-payload-8.4.1.0-53.REL \
--port 26dcc1c9-cd63-42b1-80f2-09f14e8191e7 \
--port e98eec84-1b24-4c06-841e-c1f5934d4dcc \
--port 06beef4a-292a-4f7f-b079-e52523e7570e \
--port c69db016-eec2-4fc8-8706-2ad096e4b41f \
--port ee450d71-8795-4e91-8a2c-a817f4044a3b \
--config-drive True \
--user-data /home/affirmed/CSM-100-1-sriov-red-config.xml
