#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source start.sh

write_env_file() {
  scope="$1"
  token="$2"

  service=$(service_name "$scope")
  image=$(image_name "$scope")
  user=$(whoami)

  env_file="$PWD/$service.env"

  env_lines=("RUNNER_TARGET_URL=https://github.com/$scope"                  
              "RUNNER_LABELS=ubuntu-latest"                                  
              "RUNNER_TOKEN=$token")

  # Ensure the file exists                                                  
  touch "$env_file"                                                         

  # Extract existing keys from the file                                     
  existing_keys=$(awk -F= '{print $1}' "$env_file")                         
                                                                              
  for line in "${env_lines[@]}"; do
    # Extract key from the line to be added                                 
    key=$(echo "$line" | awk -F= '{print $1}')                              
                                                                            
    # Check if the key exists in the existing keys                          
    if ! echo "$existing_keys" | grep -q "^$key$"; then                     
      echo "$line" >> "$env_file"                                           
    fi                                                                      
  done   
}

create_systemd_service() {
  scope="$1"
  token="$2"

  # Check if the systemd directory exists
  if [ ! -d "/etc/systemd/system" ]; then
    echo "Systemd directory not found"
    exit 1
  fi
  
  service=$(service_name "$scope")
  image=$(image_name "$scope")

  # Find the docker binary
  docker="$(which docker || echo "/usr/bin/docker")"

  # Create the systemd service file
  cat <<EOF | sudo tee "/etc/systemd/system/$service.service" > /dev/null
[Unit]
Description=Self hosted GitHub runner

[Service]
Restart=always
EnvironmentFile=$env_file
ExecStartPre=-$docker rm -f $image 
ExecStart=$docker rm -f $image sh -c './config.sh --url \$RUNNER_TARGET_URL --token \$RUNNER_TOKEN --labels \$RUNNER_LABELS --unattended --ephemeral && ./run.sh'
ExecStop=$docker stop $image 

[Install]
WantedBy=default.target
EOF

  # Reload systemd daemon
  sudo systemctl daemon-reload

  echo "Service $service created and ready to start. Run './start.sh' to start the service."
}

check_and_install_docker() {                                              
  user=$(whoami)
  if ! command -v docker &> /dev/null; then                             
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
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

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
      -t|--token)
        token="$2"
        shift
        ;;
      -s|--scope)
        scope="$2"
        shift
        ;;
      *)
        echo "Unknown option: $key"
        exit 1
        ;;
    esac
    shift
  done

  if [ -z "${scope+x}" ]; then
    echo "--scope is required (e.g. 'org' or 'owner/repo')"
    exit 1
  fi

  if [ -z "${token+x}" ]; then
    echo "--token is required."
    if [[ "$scope" == *"/"* ]]; then
      echo "Visit https://github.com/$scope/settings/actions/runners/new?arch=x64&os=linux"
    else
      echo "Visit https://github.com/organizations/$scope/settings/actions/runners/new?arch=x64&os=linux"
    fi
    
    exit 1
  fi


  check_and_install_docker
  write_env_file "$scope" "$token"
  create_systemd_service "$scope" "$token"
}

 # Execute the main function only if the script is called directly         
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then                              
    main "$@"                                                             
fi    