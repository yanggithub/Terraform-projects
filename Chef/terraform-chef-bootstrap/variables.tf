#################################################
# Variables for Chef
#################################################
variable "vm_list" {
  type = list(object({
    vm_name      = string
    vm_ip        = string
    vm_os        = string
    ssh_user     = optional(string)
    vm_ssh_key   = optional(string)
    chef_env     = optional(string)
    chef_runlist = optional(list(string))
  }))
  default = []
}

#################################################
#
#################################################
variable "winrm_user" {
  type    = string
  default = null
}

variable "winrm_password" {
  type      = string
  default   = null
  sensitive = true
}

######################################################
# Variables for ssh into chef workstation
# We run knife command from Chef ws to bootstrap nodes
#######################################################
variable "chef_ws_host" {
  description = "IP or resolvale hostname for Chef ws."
  type        = string
  default     = null
}

variable "chef_ws_user" {
  description = "User on Chef ws to run knife commands"
  type        = string
  default     = null
}

variable "chef_ws_ssh_key" {
  description = "Path to the private key for ssh into Chef ws.(on terraform workstation)"
  type        = string
  default     = null
}

variable "secret_ad" {
  description = "AWS secret manager name for AD credential"
  type        = string
  default     = null
}

variable "local_chef_ws" {
  description = "True if you are running Terraform and Chef on the same workstation"
  type        = bool
  default     = false
}

variable "chef_env" {
  description = "Chef env to add the vm"
  type        = string
  default     = null
}

variable "chef_runlist" {
  description = "Chef runlist at node bootstrap time"
  type        = list(string)
  default     = []
}

variable "bootstrap_addon_param" {
  description = "Addon parameterss for chef bootstrap"
  ## e.g. ["--chef-license", "accept"]
  type    = list(string)
  default = []
}

variable "vm_ssh_key_on_chef_ws" {
  description = "ssh private key path on chef ws that used to ssh into new node."
  type        = string
  default     = null
}

#################################################################################
# bastion host
#################################################################################
variable "bastion_host" {
  description = "Jump/bastion host IP for ssh into Chef ws."
  type        = string
  default     = null
}

variable "bastion_user" {
  description = "Jump/bastion host user for ssh into Chef ws."
  type        = string
  default     = null
}

variable "bastion_ssh_key" {
  description = "Path to jump/bastion host private ssh key for ssh into Chef ws."
  type        = string
  default     = null
}
