#!/bin/bash
# set -x # Uncomment to run in debug mode

###########################################
# accepted inputs
###########################################
# -a Action. Either create or delete.
# -n Node name.
# -p Node platform. Either Windows or Linux.
# -h Node private hostname/IP.
# -x User for ssh.
# -i Path to ssh private key on chef-ws
# -e Chef Envirnoment to be added to
# -r Chef runlist
# -s AWS secret name
# -m Additional/more Chef parameters for bootstrap. Passed as a string.

###########################################
# Required dependencies
###########################################
# 1. knife and knife windows plugin.
# 2. aws cli v2.
# 3. jq.

DEPENDENCIES=("knife" "aws" "jq")
for dep in "${DEPENDENCIES[@]}"; do
  if [ ! $(which ${dep}) ]; then
    echo "${dep} must be available."
    exit 1
  fi
done

while getopts "a:n:p:h:x:i:e:s:r:m:c:" opt; do
  case $opt in
  a) action=$OPTARG ;;
  n) node_name=$OPTARG ;;
  p) node_platform=$OPTARG ;;
  h) node_host=$OPTARG ;;
  x) ssh_user=$OPTARG ;;
  i) ssh_key=$OPTARG ;;
  e) chef_env=$OPTARG ;;
  s) secret_name=$OPTARG ;;
  r) chef_runlist=$OPTARG ;;
  m) addon_param=$OPTARG ;;
  c) bootstrap_vault=$OPTARG ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 2
    ;;
  esac
done

# Get the domain username and domain password to bootsrap windows node from AWS secret manager.
function get_secret() {
  if [ ! -z "${secret_name}" ]; then
    secret_obj="$(aws secretsmanager get-secret-value --secret-id ${secret_name})"
    domain_user="$(echo ${secret_obj} | jq --raw-output '.SecretString' | jq -r .UserID)"
    domain_password="$(echo ${secret_obj} | jq --raw-output '.SecretString' | jq -r .Password)"
    domain_name="$(echo ${secret_obj} | jq --raw-output '.SecretString' | jq -r .Domain)"
  else
    echo "AWS secret name/id is not defined."
    exit 3
  fi
}

function winrm_wait() {
  echo "Running winrm test to see if node ${node_name} is ready to bootstrap..."
  local count=5
  get_secret
  until [ $count -eq 0 ] || knife winrm -m ${node_host} -x "${domain_user}" -P "${domain_password}" >/dev/null 2>&1; do
    echo "Winrm test failed. Retry in 60 second..."
    sleep 60
    ((count -= 1))
  done
}

function delete_node() {
  knife_cmd="knife node delete ${node_name} -y"
  eval $knife_cmd
}

function bootsrap_node() {
  knife_cmd=""
  if [ ${node_platform} == "Linux" ]; then
    rand=$(( 180 + $RANDOM % 100 ))
    echo "Sleeping ${rand} second for Linux server to get ready."
    sleep $rand
    knife_cmd="knife bootstrap ${node_host} -x ${ssh_user} -i ${ssh_key} --sudo -N ${node_name} --no-host-key-verify"
  elif [ ${node_platform} == "Windows" ]; then
    winrm_wait
    rand_win=$(( $RANDOM % 100 ))
    echo "Sleeping ${rand_win} second to spread load evenly for chef bootstrap"
    sleep $rand_win
    get_secret
    knife_cmd="knife bootstrap windows winrm ${node_host} -x ${domain_user} -P ${domain_password} -N ${node_name}"
  else
    echo "Node platform is not defined."
    exit 4
  fi

  # Append chef environment to bootstrap command
  if [ ! -z "${chef_env}" ]; then
    knife_cmd=$knife_cmd" -E ${chef_env}"
  fi

  # Append chef run_list to bootstrap command
  if [ ! -z "${chef_runlist}" ]; then
    knife_cmd=$knife_cmd" -r ${chef_runlist}"
  fi

  # Append chef vault need to access to bootstrap command
  if [ ! -z "${bootstrap_vault}" ]; then
    knife_cmd=$knife_cmd" --bootstrap-vault-json '"${bootstrap_vault}"'"
  fi

  # Append addon chef parameter, and --yes for override existing node.
  if [ ! -z "${addon_param}" ]; then
    knife_cmd=$knife_cmd" ${addon_param} --yes"
  else
    knife_cmd=$knife_cmd" --yes"
  fi
  # echo $knife_cmd # Uncomment to run in debug mode
  eval $knife_cmd
}

if [ ${action} == "bootstrap" ]; then
  echo "Bootstraping node ${node_name}"
  bootsrap_node
elif [ ${action} == "delete" ]; then
  echo "Deleting chef node ${node_name}"
  delete_node
else
  echo "Have to define either bootstrap or delete a node"
  exit 5
fi
