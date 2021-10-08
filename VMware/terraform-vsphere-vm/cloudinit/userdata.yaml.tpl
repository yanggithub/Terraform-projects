#cloud-config

# user module.
# Create users and install ssh public keys
users:
  - default
  - name: ${ssh_user}
    primary_group: ${ssh_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, wheel
    ssh_import_id: None
    lock_passwd: true
    ssh_authorized_keys:
    - ${ssh_public_key}

# Set Hostname module
# Update Server hostname
manage_etc_hosts: "localhost"
fqdn: ${fqdn}
hostname: ${host_name}
