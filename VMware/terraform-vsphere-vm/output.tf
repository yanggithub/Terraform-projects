# output "vsphere_datacenter_name" {
#   description = "Name of vSphere Datacenter"
#   value       = data.vsphere_datacenter.dc.name
# }

# output "vsphere_cluster_name" {
#   description = "Name of vSphere cluster"
#   value       = one(data.vsphere_compute_cluster.compute_cluster[*].name)
# }

# output "vsphere_pool_name" {
#   description = "Name of vSphere Resource Pool."
#   value       = data.vsphere_resource_pool.pool[0].name
# }

output "vsphere_vm_list" {
  value = [
    for i in local.vm_output : merge({
      vm_name = i.name
      vm_ip   = i.default_ip_address
      vm_os   = var.vm_os
      vm_uuid = i.uuid
      },
      local.ssh_info
    )
  ]
}
