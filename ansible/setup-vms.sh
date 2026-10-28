#!/usr/bin/env bash
# Create the lab VMs on the remote libvirt host.
set -euo pipefail
cd "$(dirname "$0")"
exec ansible-playbook vms.yml --ask-become-pass "$@"
