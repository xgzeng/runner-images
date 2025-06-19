#!/bin/bash -e

# remove default user, implemented with walinuxagent module
python3 -c "from azurelinuxagent.common.osutil import get_osutil; \
   get_osutil().del_account('ubuntu');"

cloud-init clean

# disable service for Azure/AWS
systemctl disable walinuxagent
systemctl disable snap.amazon-ssm-agent.amazon-ssm-agent
systemctl disable hibinit-agent
