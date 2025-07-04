#!/bin/bash -e

# remove default user, implemented with walinuxagent module
python3 -c "from azurelinuxagent.common.osutil import get_osutil; \
   get_osutil().del_account('ubuntu');"

cloud-init clean

# disable service for Azure/AWS cloud providers

## Microsoft Azure Linux Guest Agent
if systemctl is-enabled walinuxagent >/dev/null 2>&1; then
    systemctl disable walinuxagent
fi

## Amazon SSM Agent
if systemctl is-enabled snap.amazon-ssm-agent.amazon-ssm-agent >/dev/null 2>&1; then
    systemctl disable snap.amazon-ssm-agent.amazon-ssm-agent
fi

## Amazon Linux hibernation agent
if systemctl is-enabled hibinit-agent >/dev/null 2>&1; then
    systemctl disable hibinit-agent
fi
