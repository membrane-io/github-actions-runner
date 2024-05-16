#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source start.sh

env_file_path() {
  local scope="$1"
  echo "$PWD/$(service_name "$scope").env"
}

write_envs() {
  local env_file=$1
  shift
  new_keys=()
  new_values=()

  # Parse input arguments into arrays for keys and values
  for arg in "$@"; do
    IFS='=' read -r key value <<<"$arg"
    new_keys+=("$key")
    new_values+=("$value")
  done

  tmpfile=$(mktemp)
  processed_keys=()

  # If the file exists, process it line by line
  if [[ -f "$env_file" ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      # Preserve comments and empty lines
      if [[ "$line" =~ ^\s*# ]] || [[ -z "$line" ]]; then
        echo "$line" >>"$tmpfile"
        continue
      fi

      # Parse lines into file_key and file_value
      IFS='=' read -r file_key file_value <<<"$line"
      file_key=$(echo "$file_key" | xargs)
      file_value=$(echo "$file_value" | xargs)

      # Check if the key exists in new_keys
      found=0
      for i in "${!new_keys[@]}"; do
        if [[ "${new_keys[$i]}" == "$file_key" ]]; then
          processed_keys+=("${new_keys[$i]}")
          # Update the value as needed
          if [[ -z "${new_values[$i]}" ]]; then
            # If the new value is empty, retain the original value
            echo "$file_key=$file_value" >>"$tmpfile"
          else
            echo "$file_key=${new_values[$i]}" >>"$tmpfile"
          fi
          found=1
          break
        fi
      done

      # Retain the original line if the key wasn't found in new_keys
      if [[ $found -eq 0 ]]; then
        if [[ -z $file_value ]]; then
          echo "$file_key=" >>"$tmpfile"
        else
          echo "$file_key=$file_value" >>"$tmpfile"
        fi
        processed_keys+=("$file_key")
      fi
    done <"$env_file"
  fi

  # Append remaining new keys/values that were not in the original file
  for i in "${!new_keys[@]}"; do
    if [[ ! " ${processed_keys[*]:-} " =~ " ${new_keys[$i]} " ]]; then
      if [[ -z "${new_values[$i]}" ]]; then
        echo "${new_keys[$i]}=" >>"$tmpfile"
      else
        echo "${new_keys[$i]}=${new_values[$i]}" >>"$tmpfile"
      fi
    fi
  done

  # Replace the original file with the temporary file
  mv "$tmpfile" "$env_file"
}

create_systemd_service() {
  local scope="$1"
  local token="$2"
  local labels="$3"

  # Check if the systemd directory exists
  if [ ! -d "/etc/systemd/system" ]; then
    echo "Systemd directory not found"
    exit 1
  fi

  local service=$(service_name "$scope")
  local image=$(image_name "$scope")
  local env_file=$(env_file_path "$scope")

  # Write environment variables for the dockerfile to use
  write_envs "$env_file" "RUNNER_NAME=$(hostname)" "RUNNER_URL=https://github.com/$scope" "RUNNER_TOKEN=$token" "RUNNER_LABELS=$labels"

  # Find the docker binary
  docker="$(which docker || echo "/usr/bin/docker")"

  # Create the systemd service file
  cat <<EOF | sudo tee "/etc/systemd/system/$service.service" >/dev/null
[Unit]
Description=Self hosted GitHub runner

[Service]
Restart=always
ExecStartPre=-$docker rm -f $image 
ExecStart=$docker run --env-file $env_file --rm --name $image $image
ExecStop=$docker stop $image 

[Install]
WantedBy=default.target
EOF

  # Reload systemd daemon
  sudo systemctl daemon-reload

  echo "Service $service created and ready to start. Run './start.sh' to start the service."
}

check_and_install_docker() {
  local user=$(whoami)
  if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Installing Docker..."

    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add the current user to the docker group to allow running docker without sudo
    sudo usermod -aG docker "$user"
    echo "Docker has been installed. You might need to log out and log back in to use Docker without sudo."
  else
    echo "Docker is already installed."
  fi
}

main() {
  # Check if the script is being run as root
  if [ "$EUID" -eq 0 ]; then
    echo "This script must not be run as root or with sudo."
    exit 1
  fi

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -t | --token)
      token="$2"
      shift
      ;;
    -s | --scope)
      scope="$2"
      shift
      ;;
    -l | --labels)
      labels="$2"
      shift
      ;;
    *)
      echo "Unknown option: $key"
      exit 1
      ;;
    esac
    shift
  done

  if [ -z "${scope:-}" ]; then
    echo "--scope is required (e.g. 'org' or 'owner/repo')"
    exit 1
  fi

  # shellcheck disable=SC1090
  source $(env_file_path "$scope")

  token="${token:-${RUNNER_TOKEN:-}}"
  if [ -z "${token:-}" ]; then
    echo "--token is required."
    if [[ "$scope" == *"/"* ]]; then
      echo "Visit https://github.com/$scope/settings/actions/runners/new?arch=x64&os=linux"
    else
      echo "Visit https://github.com/organizations/$scope/settings/actions/runners/new?arch=x64&os=linux"
    fi

    exit 1
  fi

  check_and_install_docker
  create_systemd_service "$scope" "$token" "${labels:-}"
}

# Execute the main function only if the script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
