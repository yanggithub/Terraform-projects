
resource "null_resource" "vm_power_off" {
  count = var.vm_power_off == true ? length(var.vm_list) : 0
  provisioner "local-exec" {
    command    = "echo \"Poweroff node ${var.vm_list[count.index].vm_name}\" && govc vm.power -s=true ${var.vm_list[count.index].vm_name}"
    on_failure = continue
    environment = {
      GOVC_URL      = var.vsphere_server
      GOVC_USERNAME = var.vsphere_user
      GOVC_PASSWORD = var.vsphere_password
      GOVC_INSECURE = true
    }
  }
}

########################################################################
# todo
# do we need vm_power_on?
########################################################################