
# satellite config
#export satellite_server='pod2-satellite.cloud.practice.redhat.com'
#export satellite_server_ip='10.12.134.15'
#export activation_key='osp13-director-dev'
export organization='core'
export pool='8a85f99a67cdc3e701681095609a0e3a'

export hostname='undercloud-core'
export ip_address='10.255.5.205'
export domain='wwtatc.com'
export stack_password='redhatvco'
export osp_version='13'

export stack_name='overcloud'
export ntp_server='10.255.0.1'

home=~
rcfile=$home/$stack_name
rcfile+="rc"
export rcfile
