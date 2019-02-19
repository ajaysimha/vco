
# satellite config
export satellite_server='pod2-satellite.cloud.practice.redhat.com'
export satellite_server_ip='10.12.134.15'
export activation_key='osp13-director-dev'
export organization='pod2'
#export pool='8a85f98c60c2c2b40160c32447481b48'

export hostname='pod2-undercloud'
export ip_address='10.12.134.20'
export domain='cloud.practice.redhat.com'
export stack_password='redhat'
export osp_version='13'

export stack_name='overcloud'
export ntp_server='clock.corp.redhat.com'
#export log_server_hostname='pod2-logmon'
#export log_server_ip='10.12.34.8'

home=~
rcfile=$home/$stack_name
rcfile+="rc"
export rcfile