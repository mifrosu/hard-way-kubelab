#!/usr/bin/env bash
# Create the lab network on the remote libvirt host.
set -euo pipefail
cd "$(dirname "$0")"
exec ansible-playbook site.yml "$@"
