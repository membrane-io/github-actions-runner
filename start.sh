#!/bin/bash
set -euo pipefail

build_image() {
  image="$1"
  docker pull ghcr.io/actions/actions-runner:latest
  docker build -t "$image" .
}

image_name() {
  scope="$1"
  echo "$scope/github-runner"
}

service_name() {
  scope="$1"
  if [[ "$scope" == */* ]]; then
    owner="${scope%%/*}"                                              
    repo="${scope##*/}"                                              
    echo "github-runner.$owner.$repo"
  else
    echo "github-runner.$scope"
  fi
}

main() {
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
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
    echo "Scope is required (e.g. 'org' or 'owner/repo')"
    exit 1
  fi

  service=$(service_name "$scope")
  image=$(image_name "$scope")

  build_image "$image"

  # Enable the service if it is not already enabled                         
  if ! systemctl is-enabled --quiet "$service"; then                   
    systemctl enable "$service"                                        
    echo "Service $service has been enabled."                          
  else                                                                      
    echo "Service $service is already enabled."                        
  fi 

  # Check if the service is active                                          
  if systemctl is-active --quiet "$service"; then                      
    # Restart the service if it's already running                           
    systemctl restart "$service"                                       
    echo "Service $service has been restarted."                        
  else                                                                      
    # Start the service if it's not running                                 
    systemctl start "$service"                                         
    echo "Service $service has been started."                          
  fi
}

 # Execute the main function only if the script is called directly         
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then                              
    main "$@"                                                             
fi    