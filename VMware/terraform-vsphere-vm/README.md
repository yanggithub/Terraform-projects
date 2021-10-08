# Terraform vSphere Module

This module deploys VMs on VMware vSphere cluster. I took the [Terraform vSphere module](https://github.com/Terraform-VMWare-Modules/terraform-vsphere-vm) from Terraform registry as reference. And added a few changes(could be in a good or bad way) to meet my needs. The changes that I added are:

- Instead of only cloning from local VMs, I added a feature to allow download ovf template from remote location(e.g. S3 bucket) via http/https. My workflow will be download the very first VM from S3 bucket, and then create the rest n-1 VMs by cloning from the first one.
- For Linux VMs, I use cloud init scripts to setup user account and install the ssh public key so that I don't have to use a hardcoded credential for ssh. The username and public key are base64 encoded and passed as user data via [vSphere guestinfo interface](https://github.com/vmware-archive/cloud-init-vmware-guestinfo).


## Getting started
The following example launch the VM by download the ovf template from S3 bucket via https. 

```hcl
module "example-server-linux" {
  source             = "../"
  vsphere_deployment = true

  ## vSphere config
  dc              = "SanFrancisco"
  datastore       = "VMFS_EDU_001"
  compute_cluster = "EDU"
  vsphere_pool    = "yxu-blue-pool"
  vsphere_hosts   = ["esx-001.yang.com", "esx-002.yang.com"]

  ## VM config
  server_type    = "ngnx"
  instance_count = 2
  node_name      = "yxu"
  domain_suffix  = "yang.com"
  cpu_number     = 2
  ram_size_gb    = 2
  remote_ovf_url = "https://my_s3_object_url/my_nginx.ovf"
  network = {
    "Subnet_10.100.0" = [],
    "EXA_EDU"         = []
  }
  data_disk = {
    root = {
      size_gb = 20
    }
    # # Tags has to be created first, before associate to VMs
    # tags = {
    #   Service    = "ngnx",
    #   Env        = "dev",
    #   Managed_by = "Terraform",
    # }
  }
}
```
The second example create VMs by cloning from local template. In the real world, I create Terraform workflow modules that chain the individual modules together, and use terragrunt to read the output from upstream module for tempalte name and template uuid, and then feed to this module so that I don't have to update tempalte name and uuid manually.

```hcl
module "vsphere_vms" {
  source   = "../terraform-vsphere-vm/"
  vsphere_deployment = true

  ## vSphere config
  dc              = "SanFrancisco"
  datastore       = "VMFS_EDU_001"
  compute_cluster = "EDU"
  vsphere_pool    = "yxu-blue-pool"
  vsphere_hosts   = ["esx-001.yang.com", "esx-002.yang.com"]

  # VM config
  instance_count      = 2
  vm_os               = "linux"
  local_template_name = $template_name
  local_template_id   = $template_uuid
  node_name           = "yxu"
  domain_suffix       = "yang.com"
  ssh_user            = "yxu"
  vm_ssh_key          = "~/.ssh/dev.pem"
  cpu_number          = 2
  ram_size_gb         = 2
  network = {
    "Subnet_10.100.0" = [],
    "EXA_EDU"         = []
  }
  data_disk = {
    root = {
      size_gb = 20
    }
    # # Tags has to be created first, before associate to VMs
    # tags = {
    #   Service    = "ngnx",
    #   Env        = "dev",
    #   Managed_by = "Terraform",
    # }
  }
  dns_server_list     = ["8.8.8.8"]
  guest_id            = "centos7_64Guest"
  # Tags has to be pre-created on vsphere before can be associated to VM.
  tags = {
    Service    = "nginx"
    OS         = "linux"
    Managed_by = "Terraform"
  }
}

```
## Output
The output for this module looks like the following. All the VMs will be printed to the output as a list of maps. 

```
Outputs:

example-server-linux = {
  "vsphere_cluster_name" = "EDU"
  "vsphere_datacenter_name" = "SFO"
  "vsphere_pool_name" = "yxu-blue-pool"
  "vsphere_vm_list" = [
    {
      "lb_pool" = "blue"
      "server_type" = "ngnx"
      "vm_ip" = "10.100.0.199"
      "vm_name" = "yxu-1.yang.com"
    },
    {
      "lb_pool" = "blue"
      "server_type" = "ngnx"
      "vm_ip" = "10.100.0.202"
      "vm_name" = "yxu-2.yang.com"
    },
  ]
}
```