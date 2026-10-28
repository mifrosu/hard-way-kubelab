#!/usr/bin/env bash
# Remove the lab network from the remote libvirt host.
set -euo pipefail
cd "$(dirname "$0")"
exec ansible-playbook teardown.yml --ask-become-pass "$@"
