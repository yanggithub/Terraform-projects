variable "vsphere_user" {
  type      = string
  sensitive = true
}

variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "vsphere_server" {
  type = string
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  # if you have a self-signed cert
  allow_unverified_ssl = true
}

# Deploy 2 linux nginx VMs
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

output "example-server-linux" {
  value = module.example-server-linux
}
