# provider "vsphere" {
#   user           = var.vsphere_user
#   password       = var.vsphere_password
#   vsphere_server = var.vsphere_server

#   # if you have a self-signed cert
#   allow_unverified_ssl = true
# }

data "vsphere_datacenter" "dc" {
  name = var.dc
}

data "vsphere_compute_cluster" "compute_cluster" {
  count         = var.compute_cluster != "" ? 1 : 0
  name          = var.compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  count         = var.datastore != "" ? 1 : 0
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

# # data "vsphere_datastore" "disk_datastore" {
# #   count         = var.disk_datastore != "" ? 1 : 0
# #   name          = var.disk_datastore
# #   datacenter_id = data.vsphere_datacenter.dc.id
# # }

data "vsphere_resource_pool" "pool" {
  count         = var.vsphere_pool != null ? 1 : 0
  name          = var.vsphere_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_vapp_container" "vapp_container" {
  count         = var.vapp_container != null && var.vapp_container != "" ? 1 : 0
  name          = var.vapp_container
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  count         = length(var.network)
  name          = keys(var.network)[count.index]
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "local_template" {
  count         = var.local_template_name != null ? 1 : 0
  name          = var.local_template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_tag_category" "category" {
  count      = var.tags != null ? length(var.tags) : 0
  name       = keys(var.tags)[count.index]
  depends_on = [var.tag_depends_on]
}

data "vsphere_tag" "tag" {
  count       = var.tags != null ? length(var.tags) : 0
  name        = var.tags[keys(var.tags)[count.index]]
  category_id = data.vsphere_tag_category.category[count.index].id
  depends_on  = [var.tag_depends_on]
}

data "vsphere_host" "host" {
  count         = length(var.vsphere_hosts) > 0 ? length(var.vsphere_hosts) : 0
  name          = var.vsphere_hosts[count.index]
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_ovf_vm_template" "ovf" {
  count            = var.remote_ovf_url != null ? 1 : 0
  name             = "ovf_temp"
  resource_pool_id = data.vsphere_resource_pool.pool[0].id
  datastore_id     = data.vsphere_datastore.datastore[0].id
  host_system_id   = data.vsphere_host.host[0].id
  remote_ovf_url   = var.remote_ovf_url
  # ovf_network_map = {
  #   "Network 1": data.vsphere_network.net.id
  # }
}

data "template_file" "userdata" {
  count    = var.vm_os != "Windows" ? var.instance_count : 0
  template = file("${path.module}/cloudinit/userdata.yaml.tpl")
  vars = {
    "ssh_user"       = var.ssh_user
    "ssh_public_key" = var.vm_ssh_key != null ? file("${var.vm_ssh_key}.pub") : ""
    "host_name"      = var.instance_count > 1 || var.use_num_suffix ? format("%s${var.num_suffix_format}", var.node_name, count.index + 1 + var.server_initial_index) : var.node_name
    "fqdn"           = var.instance_count > 1 || var.use_num_suffix ? join(".", [format("%s${var.num_suffix_format}", var.node_name, count.index + 1 + var.server_initial_index), var.domain_suffix]) : join(".", [var.node_name, var.domain_suffix])
  }
}

data "template_cloudinit_config" "userdata" {
  count         = var.vm_os != "Windows" ? var.instance_count : 0
  gzip          = true
  base64_encode = true
  part {
    filename     = "userdata.yaml"
    content_type = "text/cloud-config"
    content      = data.template_file.userdata[count.index].rendered
  }
}

# data "template_file" "metadata" {
#   count    = var.is_windows_image == true ? 0 : var.instance_count
#   template = file("${path.module}/cloudinit/metadata.yaml.tpl")
#   vars = {
#     "hostname" = var.instance_count > 1 || var.use_num_suffix ? join(".", [format("%s${var.num_suffix_format}", var.node_name, count.index + 1 + var.server_initial_index), var.domain_suffix]) : join(".", [var.node_name, var.domain_suffix])
#   }
# }

# data "template_cloudinit_config" "metadata" {
#   count    = var.is_windows_image == true ? 0 : var.instance_count
#   gzip          = true
#   base64_encode = true
#   part {
#     filename     = "metadata.yaml"
#     content_type = "text/cloud-config"
#     content      = data.template_file.metadata[count.index].rendered
#   }
# }


#############################################################################################################################
## Create VMs
## When var.remote_ovf_url != null, create new VMs by import from remote ovf template.
## When var.remote_ovf_url == null, create new VMs by use local VM as template.
#############################################################################################################################

locals {
  ## Prepare local var for dynamic ovf_deploy block when create new VMs from remote ovf template
  ovf_deploy = var.remote_ovf_url != null ? { ovf_deploy = { remote_ovf_url = var.remote_ovf_url } } : {}

  ## Prepare local var for dynamic clone block when create new VMs by copy local VM template
  ## Have to use template uuid when copy local VMs. Use data block to parse uuid will case VM to be replaced,
  ## due to uuid is unknown at the TF plan time.
  clone = var.local_template_id != null ? { clone = { template_uuid = var.local_template_id } } : {}
  network_interface = {
    for k, v in var.network : k => {
      dns_server_list = var.dns_server_list,
      dns_domain      = var.domain_suffix
    }
  }
}
resource "vsphere_virtual_machine" "vm" {
  count = var.remote_ovf_url != null ? 1 : var.instance_count
  # depends_on = [var.vm_depends_on]

  #############################################################################################
  ## vSphere cluster config
  #############################################################################################
  ## datacenter_id is only required when import from remote ovf.
  datacenter_id = var.remote_ovf_url != null ? data.vsphere_datacenter.dc.id : null
  datastore_id  = data.vsphere_datastore.datastore[0].id
  ## Looks like it is not supported to use vapp_container if import from ovf
  resource_pool_id        = var.vapp_container != null && var.remote_ovf_url == null ? data.vsphere_vapp_container.vapp_container[0].id : data.vsphere_resource_pool.pool[0].id
  host_system_id          = element(distinct(compact(data.vsphere_host.host[*].id)), count.index)
  folder                  = var.vmfolder
  tags                    = var.tag_ids != null ? var.tag_ids : data.vsphere_tag.tag[*].id
  custom_attributes       = var.custom_attributes
  annotation              = var.annotation
  firmware                = var.firmware
  efi_secure_boot_enabled = var.efi_secure_boot
  enable_disk_uuid        = var.enable_disk_uuid
  storage_policy_id       = var.storage_policy_id

  #############################################################################################
  # VM config
  #############################################################################################
  name                   = var.instance_count > 1 || var.use_num_suffix ? join(".", [format("%s${var.num_suffix_format}", var.node_name, count.index + 1 + var.server_initial_index), var.domain_suffix]) : join(".", [var.node_name, var.domain_suffix])
  num_cpus               = var.cpu_number != null ? var.cpu_number : data.vsphere_ovf_vm_template.ovf[0].num_cpus
  num_cores_per_socket   = var.num_cores_per_socket != null ? var.num_cores_per_socket : data.vsphere_ovf_vm_template.ovf[0].num_cores_per_socket
  cpu_hot_add_enabled    = var.cpu_hot_add_enabled
  cpu_hot_remove_enabled = var.cpu_hot_remove_enabled
  cpu_reservation        = var.cpu_reservation
  memory_reservation     = var.memory_reservation
  memory                 = var.ram_size_gb != null ? var.ram_size_gb * 1024 : data.vsphere_ovf_vm_template.ovf[0].memory
  memory_hot_add_enabled = var.memory_hot_add_enabled
  guest_id               = coalesce(var.guest_id, one(data.vsphere_ovf_vm_template.ovf[*].guest_id), one(data.vsphere_virtual_machine.local_template[*].guest_id))
  scsi_bus_sharing       = var.scsi_bus_sharing
  scsi_type              = coalesce(one(data.vsphere_ovf_vm_template.ovf[*].scsi_type), one(data.vsphere_virtual_machine.local_template[*].scsi_type), "lsilogic-sas")
  scsi_controller_count = max(max(0, flatten([
    for item in values(var.data_disk) : [
      for elem, val in item :
      elem == "data_disk_scsi_controller" ? val : 0
    ]
  ])...) + 1, var.scsi_controller)
  wait_for_guest_net_routable = var.wait_for_guest_net_routable
  wait_for_guest_ip_timeout   = var.wait_for_guest_ip_timeout
  wait_for_guest_net_timeout  = var.wait_for_guest_net_timeout
  ignored_guest_ips           = var.ignored_guest_ips

  dynamic "network_interface" {
    for_each = keys(var.network)
    content {
      network_id = data.vsphere_network.network[network_interface.key].id
      # adapter_type = var.network_type != null ? var.network_type[network_interface.key] : data.vsphere_virtual_machine.template.network_interface_types[0]
    }
  }

  // Additional disks defined by Terraform config
  dynamic "disk" {
    for_each = var.data_disk
    iterator = terraform_disks
    content {
      label       = terraform_disks.key
      size        = lookup(terraform_disks.value, "size_gb", null)
      unit_number = index(keys(var.data_disk), terraform_disks.key)
      # unit_number       = lookup(terraform_disks.value, "data_disk_scsi_controller", 0) ? terraform_disks.value.data_disk_scsi_controller * 15 + index(keys(var.data_disk), terraform_disks.key) + (var.scsi_controller == tonumber(terraform_disks.value["data_disk_scsi_controller"]) ? local.template_disk_count : 0) : index(keys(var.data_disk), terraform_disks.key) + local.template_disk_count
      thin_provisioned  = lookup(terraform_disks.value, "thin_provisioned", true)
      eagerly_scrub     = lookup(terraform_disks.value, "eagerly_scrub", false)
      datastore_id      = lookup(terraform_disks.value, "datastore_id", null)
      storage_policy_id = lookup(terraform_disks.value, "storage_policy_id", null)
    }
  }

  ## Dynamic blocks for launch new VMs from difference sources. https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs/resources/virtual_machine
  ## Will have ovf_deploy block if launch from remote ovf template.
  ## Will have clone block if launch from local VM template.
  dynamic "ovf_deploy" {
    for_each = local.ovf_deploy
    content {
      remote_ovf_url            = ovf_deploy.value.remote_ovf_url
      allow_unverified_ssl_cert = true
      ip_protocol               = var.ip_protocol
      disk_provisioning         = "thin"
    }
  }

  dynamic "clone" {
    for_each = local.clone
    content {
      template_uuid = clone.value.template_uuid

      dynamic "customize" {
        for_each = var.vm_os == "Windows" ? local.clone : {}
        content {
          dynamic "windows_options" {
            for_each = var.vm_os == "Windows" ? local.clone : {}
            content {
              computer_name     = var.instance_count > 1 || var.use_num_suffix ? format("%s${var.num_suffix_format}", var.node_name, count.index + 1 + var.server_initial_index) : var.node_name
              organization_name = var.domain_suffix != null ? var.domain_suffix : "yang"
            }
          }

          dynamic "network_interface" {
            for_each = var.vm_os == "Windows" ? local.network_interface : {}
            content {
              dns_server_list = network_interface.value.dns_server_list
              dns_domain      = network_interface.value.dns_domain
            }
          }
        }
      }
    }
  }

  extra_config = {
    "guestinfo.userdata"          = length(data.template_cloudinit_config.userdata) > 0 ? data.template_cloudinit_config.userdata[count.index].rendered : null
    "guestinfo.userdata.encoding" = length(data.template_cloudinit_config.userdata) > 0 ? "gzip+base64" : null
    # "guestinfo.metadata"          = data.template_cloudinit_config.metadata[count.index].rendered
    # "guestinfo.metadata.encoding" = "gzip+base64"
  }

  // Advanced options
  hv_mode                          = var.hv_mode
  ept_rvi_mode                     = var.ept_rvi_mode
  nested_hv_enabled                = var.nested_hv_enabled
  enable_logging                   = var.enable_logging
  cpu_performance_counters_enabled = var.cpu_performance_counters_enabled
  swap_placement_policy            = var.swap_placement_policy
  latency_sensitivity              = var.latency_sensitivity

  shutdown_wait_timeout = var.shutdown_wait_timeout
  force_power_off       = var.force_power_off

  lifecycle {
    ignore_changes = [
      host_system_id
    ]
  }
}

locals {
  # Aggregate all VM outputs together that created from difference resources.
  vm_output = concat(vsphere_virtual_machine.vm)
  ssh_info = var.vm_os == "Windows" ? {
    ssh_user   = null,
    vm_ssh_key = null
    } : {
    ssh_user   = var.ssh_user,
    vm_ssh_key = var.vm_ssh_key
  }
}
