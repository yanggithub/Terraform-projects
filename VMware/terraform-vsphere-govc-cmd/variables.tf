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

variable "vm_power_off" {
  description = "Poweroff the VM after create."
  type        = bool
  default     = false
}

variable "vm_list" {
  type = list(object({
    vm_name = string
  }))
  default = []
}
