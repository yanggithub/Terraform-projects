# instance-id: cloud-vm
local-hostname: ${hostname}
network:
  version: 2
  ethernets:
    nics:
      match:
        name: ens*
      dhcp4: yes