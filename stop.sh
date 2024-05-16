#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source start.sh

main() {
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -s | --scope)
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
  sudo systemctl mask "$service"
  sudo systemctl stop "$service"
  sudo systemctl disable "$service"
  sudo systemctl unmask "$service"
  # shellcheck disable=SC2015
  docker stop "$service" || true && docker rm -f "$service" || true
}

# Execute the main function only if the script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
