####################################################################################################
# Instead of taking one VM/node object as input, we want to use a list of objects as input for that 
# type of servers.
####################################################################################################

locals {
  ## You can add default chef bootstrap parameters here as a list. e.g.
  ## local_bootstrap_addon_param = ["--node-ssl-verify-mode", "none", "--chef-license", "accept"]
  local_bootstrap_addon_param = ["--node-ssl-verify-mode", "none"]
  bootstrap_addon_param_list  = var.bootstrap_addon_param != null ? concat(var.bootstrap_addon_param, local.local_bootstrap_addon_param) : local.local_bootstrap_addon_param
  bootstrap_addon_param_str   = length(local.bootstrap_addon_param_list) > 0 ? join("\\ ", concat(["-m"], local.bootstrap_addon_param_list)) : ""
}

resource "null_resource" "chef_bootstrap" {
  count = length(var.vm_list) > 0 && !var.local_chef_ws ? length(var.vm_list) : 0

  ###################################################################################################
  # todo:
  # This is a bad implementation of triggers. We have to use triggers to pass the value of variables
  # to the remote-exec provisioner for destroy chef node. Destroy connection/provisioner can only access
  # self, cont.index or key.value.
  # Need to find a better way to pass the values.
  ####################################################################################################
  triggers = {
    ## don't think we need to use instance_id as trigger 
    # id                = var.chef_node.id
    node_name     = var.vm_list[count.index].vm_name != null ? join(" ", ["-n", var.vm_list[count.index].vm_name]) : ""
    node_host     = var.vm_list[count.index].vm_ip != null ? join(" ", ["-h", var.vm_list[count.index].vm_ip]) : ""
    node_platform = var.vm_list[count.index].vm_os != null ? join(" ", ["-p", var.vm_list[count.index].vm_os]) : ""
    secret_ad     = var.secret_ad != null ? join(" ", ["-s", var.secret_ad]) : ""
    node_ssh_user = var.vm_list[count.index].ssh_user != null ? join(" ", ["-x", var.vm_list[count.index].ssh_user]) : ""
    node_ssh_key  = var.vm_list[count.index].vm_ssh_key != null ? join(" ", ["-i", var.vm_list[count.index].vm_ssh_key]) : ""
    chef_env      = var.vm_list[count.index].chef_env != null ? join(" ", ["-e", var.vm_list[count.index].chef_env]) : ""
    chef_runlist  = var.vm_list[count.index].chef_runlist != null ? join(" ", ["-r", join(",", var.vm_list[count.index].chef_runlist)]) : ""


    ## triggers can not be null
    chef_ws_host          = var.chef_ws_host != null ? var.chef_ws_host : ""
    chef_ws_user          = var.chef_ws_user != null ? var.chef_ws_user : ""
    chef_ws_ssh_key       = var.chef_ws_ssh_key != null ? var.chef_ws_ssh_key : ""
    bastion_host          = var.bastion_host != null ? var.bastion_host : ""
    bastion_user          = var.bastion_user != null ? var.bastion_user : ""
    bastion_ssh_key       = var.bastion_ssh_key != null ? var.bastion_ssh_key : ""
    vm_ssh_key_on_chef_ws = var.vm_ssh_key_on_chef_ws != null ? var.vm_ssh_key_on_chef_ws : ""
  }

  connection {
    type        = "ssh"
    user        = self.triggers.chef_ws_user
    host        = self.triggers.chef_ws_host
    private_key = file(self.triggers.chef_ws_ssh_key)

    ## bastion host is not mandatory if chef_ws is accessible directly.
    bastion_host        = self.triggers.bastion_host != "" ? self.triggers.bastion_host : null
    bastion_user        = self.triggers.bastion_user != "" ? self.triggers.bastion_user : null
    bastion_private_key = self.triggers.bastion_ssh_key != "" ? file(self.triggers.bastion_ssh_key) : null

    ## CIS L1 hardening requiremnts do not allow to run script under /tmp dir. Has to change default /tmp dir.
    script_path = "/home/${self.triggers.chef_ws_user}/tf-script-%RAND%.sh"
  }

  provisioner "file" {
    source      = "${path.module}/knife-bootstrap.sh"
    destination = "/home/${self.triggers.chef_ws_user}/knife-bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"Running knife command as user: $(whoami)\"",
      "chmod +x /home/${self.triggers.chef_ws_user}/knife-bootstrap.sh",
      join(" ", [
        "/home/${self.triggers.chef_ws_user}/knife-bootstrap.sh -a bootstrap",
        self.triggers.node_name,
        self.triggers.node_platform,
        self.triggers.node_host,
        self.triggers.node_ssh_user,
        self.triggers.node_ssh_key,
        self.triggers.chef_env,
        self.triggers.chef_runlist,
        self.triggers.secret_ad,
        local.bootstrap_addon_param_str
      ])
    ]
  }

  ## Destroy-time provisioners and their connection configurations may only reference attributes of the related resource, via 'self', 'count.index', or 'each.key'.
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "echo \"Running remote-exec on chef-ws triggered by destroy.\"",
      join(" ", [
        "timeout 10m /home/${self.triggers.chef_ws_user}/knife-bootstrap.sh -a delete",
        self.triggers.node_name,
        self.triggers.node_platform,
        self.triggers.node_host,
        self.triggers.node_ssh_user,
        self.triggers.node_ssh_key,
        self.triggers.secret_ad
      ])
    ]
  }
}

# Use this resource if running terraform on the same node as chef workstation.
# Provide var.local_chef_ws = true to enable this resource.
resource "null_resource" "chef_bootstrap_local_chef_ws" {
  count = length(var.vm_list) > 0 && var.local_chef_ws ? length(var.vm_list) : 0

  triggers = {
    # id            = var.chef_node.id
    node_name     = var.vm_list[count.index].vm_name != null ? join(" ", ["-n", var.vm_list[count.index].vm_name]) : ""
    node_host     = var.vm_list[count.index].vm_ip != null ? join(" ", ["-h", var.vm_list[count.index].vm_ip]) : ""
    node_platform = var.vm_list[count.index].vm_os != null ? join(" ", ["-p", var.vm_list[count.index].vm_os]) : ""
    secret_ad     = var.secret_ad != null ? join(" ", ["-s", var.secret_ad]) : ""
    node_ssh_user = var.vm_list[count.index].ssh_user != null ? join(" ", ["-x", var.vm_list[count.index].ssh_user]) : ""
    node_ssh_key  = var.vm_list[count.index].vm_ssh_key != null ? join(" ", ["-i", var.vm_list[count.index].vm_ssh_key]) : ""
    chef_env      = var.vm_list[count.index].chef_env != null ? join(" ", ["-e", var.vm_list[count.index].chef_env]) : ""
    chef_runlist  = var.vm_list[count.index].chef_runlist != null ? join(" ", ["-r", join(",", var.vm_list[count.index].chef_runlist)]) : ""
  }

  provisioner "local-exec" {
    #command = "${path.module}/knife-bootstrap.sh -a bootstrap ${self.triggers.node_name} -p ${self.triggers.node_platform} -h ${self.triggers.node_host} -x ${self.triggers.node_ssh_user} -i ${self.triggers.node_ssh_key} -s ${self.triggers.secret_ad} ${local.chef_param_str}"
    command = join(" ", [
      "${path.module}/knife-bootstrap.sh -a bootstrap",
      self.triggers.node_name,
      self.triggers.node_platform,
      self.triggers.node_host,
      self.triggers.node_ssh_user,
      self.triggers.node_ssh_key,
      self.triggers.chef_env,
      self.triggers.chef_runlist,
      self.triggers.secret_ad,
      local.bootstrap_addon_param_str
    ])
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    #command    = "timeout 10m ${path.module}/knife-bootstrap.sh -a delete -n ${self.triggers.node_name} -p ${self.triggers.node_platform} -h ${self.triggers.node_host} -x ${self.triggers.node_ssh_user} -i ${self.triggers.node_ssh_key} -s ${self.triggers.secret_ad}"
    command = join(" ", [
      "timeout 10m ${path.module}/knife-bootstrap.sh -a delete",
      self.triggers.node_name,
      self.triggers.node_platform,
      self.triggers.node_host,
      self.triggers.node_ssh_user,
      self.triggers.node_ssh_key,
      self.triggers.secret_ad
    ])
  }
}
