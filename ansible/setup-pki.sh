#!/usr/bin/env bash
# Generate the lab CA and TLS certificates locally and copy them to the VMs.
set -euo pipefail
cd "$(dirname "$0")"
exec ansible-playbook pki.yml "$@"
