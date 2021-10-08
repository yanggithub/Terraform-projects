# govc cmd module

Terraform doesn't provide feature to turn on/off the VMs, only support create/teardown, which make sense for most of the cases. You create the new servers when you need, and destroy them when nolonger needed.
However, in the real world, sometimes we have to create new servers before put them on duty in a rolling fashion due to limited hardware resources(CPU and memory), especially when you want to minimize service downtime deployment. Our producation datacenter has about 30% free capacity, which is not enough for blue/green deployment. Our approach is we create n new server at a time, then shut them down. And then create next n servers and shutdown, until we have enough servers for the green pool. During the maintaince window, we shutdown the old servers in blue pool, and start new servers in green pool. In this way, we don't have to double the datacenter capacity in order to do blue/green deployment.

## Installation
This module can be used as a wrapper to run govc commands. Before we can run this module, need to install govc tool on the workstation where runs the terraform code.
govc tool can be downloaded from: 
https://github.com/vmware/govmomi/releases

Documentation can be viewed at: 
https://github.com/vmware/govmomi/blob/master/govc/USAGE.md

Example for installation
```bash
#!/bin/bash
curl -sL https://github.com/vmware/govmomi/releases/download/v0.25.0/govc_Linux_x86_64.tar.gz -o /tmp/govc.tar.gz
cd /tmp/govc.taf.gz && tar xzvf govc.tar.gz
sudo mv govc /usr/local/bin/
```

## Usage
This module uses Terraform local-exec provisioner resource, which makes this module should only be used as last effort when Terraform vsphere provider doesn't support the feature that you want.
This module only support VM poweroff for now. But we can add more commands if required.