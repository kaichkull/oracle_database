#!/bin/bash

# This script is used to deploy the Oracle RAC.
VERSION=rac/ol8_19
export VERSION

PROJECT_FOLDER="/Users/rmastro/Documents/Dynamic/projects/kyndryl/vagrant/${VERSION}"
export PROJECT_FOLDER

# ACTION
ACTION=""
export ACTION

#
## Helper functions
###################

# This function handle arguments passed to the script
# @param oracle_sid
# @param alertlog_lines
# @param remediate
# @param custom_oratab
function handle_arguments() {
  # Ensure we have arguments, otherwise due to Bash strict mode it will
  if test "${#}" -eq 0; then
    usage
  fi

  while test "${#}" -gt 0; do
    case "${1}" in
      --project_folder=*) PROJECT_FOLDER="${1#*=}"; shift 1;; # string
      --version=*) VERSION="${1#*=}"; shift 1;; # string
      --sleep=*) SLEEP_SECONDS="${1#*=}"; shift 1;; # integer
      --action=*) ACTION="${1#*=}"; shift 1;; # string
      *) usage "Unknown option: ${1}";;
    esac
  done

}



## @fn usage()
## @brief Show help
## @param <Custom error message>
function usage() {
  local usage_message
  usage_message="$(printf 'Error: \n\t%s\nUsage: %s<options>\n' "${1}" "${0}")"
  printf '%s' "${usage_message}" ''
}

# Validate
# Validate if the GRID_SOFTWARE variable is set equal to the zip in software folder
function validate() {
   local yml_grid
   local yml_db
   local actual_grid_software
   local actual_db_software
   yml_grid="$(grep "export GRID_SOFTWARE=" "${PROJECT_FOLDER}"/config/install.env | cut -d "=" -f 2)"
   yml_db="$(grep "export DB_SOFTWARE=" "${PROJECT_FOLDER}"/config/install.env | cut -d "=" -f 2)"
   actual_db_software="$(ls ${PROJECT_FOLDER}/software | grep "LINUX.X64_193000_db_home.zip")"
   actual_grid_software="$(ls ${PROJECT_FOLDER}/software | grep "LINUX.X64_193000_grid_home.zip")"
    if test "${yml_grid}" != "${actual_grid_software}"; then
       echo "========================================================================="
      echo "The GRID_SOFTWARE variable does not match whats inside the software folder"
      echo "========================================================================="
      exit 1
    else
      echo "========================================================================="
      echo "The GRID_SOFTWARE variable matches whats inside the software folder"
      echo "========================================================================="
    fi
    if test "${yml_db}" != "${actual_db_software}"; then
      echo "========================================================================="
      echo "The DB_SOFTWARE variable does not match whats inside the software folder"
      echo "========================================================================="
      exit 1
    else
      echo "========================================================================="
      echo "The DB_SOFTWARE variable matches whats inside the software folder"
      echo "========================================================================="
    fi
}





# Storage folder ammended to the Vagrantfile
function storage_folder() {
  storage_folder="${PROJECT_FOLDER}/storage"
  if test -d "${storage_folder}"; then
    echo "Storage folder already exists, providing permissions"
    chmod -R 755 ${storage_folder}
  else
    echo "Storage folder is not created, provisioning"
    mkdir -p "${storage_folder}"
    chmod -R 755 "${storage_folder}"
  fi
}

# DNS Server
function dns_server() {
  action="${*:-up}"|| exit 127
  echo "navigating to ${PROJECT_FOLDER}/dns"
  cd ${PROJECT_FOLDER}/dns || exit 127
  echo "vagrant ${action} on dns"
  vagrant "${action}"
}

#NODE 2
function node2() {
  action="${*:-up}"
  echo "navigating to ${PROJECT_FOLDER}/node2"
  cd ${PROJECT_FOLDER}/node2 || exit 127
  echo "vagrant ${action} on node2"
  vagrant "${action}"
}

function node1() {
  action="${*:-up}"
  echo "navigating to ${PROJECT_FOLDER}/node1"
  cd ${PROJECT_FOLDER}/node1 || exit 127
  echo "vagrant ${action} on node2"
  vagrant "${action}"
}


# Build the environment
# 1. Create the storage folder
# 2. Start the DNS server
# 3. Start the second node
# 4. Stop the second node
# 5. Start the DNS server again
# 6. Start the second node again both with network reconfiguration
# 7. Start the first node for the first time
function build() {
  validate
  storage_folder
  dns_server
  node2
  node2 halt
  dns_server halt
  dns_server
  node2
  node1 up
}


# Destroy the environment
# 1. Destroy the first node
# 2. Destroy the second node
# 3. Destroy the DNS server
function destroy() {
  node1 halt
  node1 "destroy -f"
  node2 halt
  node2 "destroy -f"
  dns_server halt
  dns_server "destroy -f"
  if test -n "${PROJECT_FOLDER}"; then
    echo "Removing storage folder"
    rm -rf "${PROJECT_FOLDER}"/storage
  fi
}

function stop_servers() {
  node1 halt
  node2 halt
  dns_server halt
}

main() {
  handle_arguments "${@}"
  case "${ACTION}" in
    build) build;;
    destroy) destroy;;
    stop) stop_servers;;
    *) usage "Unknown option";;
  esac
}

main  "${@}"
