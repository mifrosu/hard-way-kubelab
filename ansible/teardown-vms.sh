#!/usr/bin/env bash
# Remove the lab VMs from the remote libvirt host.
set -euo pipefail
cd "$(dirname "$0")"
exec ansible-playbook teardown-vms.yml --ask-become-pass "$@"
