# Ansible: lab network and VMs

Playbooks that build the Kubernetes the Hard Way lab on a remote libvirt host:
a NAT network (`k8s`, `10.100.0.0/24`) and three Debian VMs created with
`virt-install`.

Everything runs through the `virsh` and `virt-install` CLIs on the remote host,
so no Python libvirt bindings are needed there.

## Layout

| Path | Purpose |
|---|---|
| `site.yml` | Define, start and autostart the lab network |
| `vms.yml` | Download the base image and create the VMs |
| `teardown-vms.yml` | Stop and undefine the VMs, delete their disks and cloud-init user-data (keeps the base image) |
| `teardown-network.yml` | Stop and undefine the lab network |
| `setup-network.sh`, `setup-vms.sh` | Wrappers for `site.yml` and `vms.yml` |
| `teardown-vms.sh`, `teardown-network.sh` | Wrappers for the teardown playbooks |
| `inventory/hosts.yml` | One host, `labhost`; its IP comes from the vault |
| `inventory/group_vars/all/vars.yml` | Network, VM and image settings |
| `inventory/group_vars/all/vault.yml.example` | Template for the encrypted vault file |
| `templates/` | libvirt network XML and cloud-init user-data |
| [`../docs/`](../docs) | Libvirt daemon setup and day-to-day VM management |

## Prerequisites

On the control machine: `ansible` and an SSH public key (default
`~/.ssh/id_ed25519.pub`). To run the checks in [Linting](#linting) you also
need `yamllint`, `ansible-lint` and `shellcheck`.

On the remote host:
- `libvirt` with its daemon sockets enabled, plus `virt-install` and `xorriso`
  (builds the cloud-init seed ISOs). See
  [LIBVIRT-DAEMONS.md](../docs/LIBVIRT-DAEMONS.md).
- SSH access for a user with sudo. The scripts prompt for the sudo password.
- The host's SSH key in your `~/.ssh/known_hosts`. Connect once by hand
  (`ssh <user>@<host>`) to accept it, because `host_key_checking` is on.

## Setup

The remote host's IP is kept in an Ansible Vault file, not in the repo.

```
cd ansible
echo 'your-vault-password' > .vault_pass && chmod 600 .vault_pass
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml
$EDITOR inventory/group_vars/all/vault.yml      # set vault_lab_host_ip
ansible-vault encrypt inventory/group_vars/all/vault.yml
```

`.vault_pass` is gitignored and is read automatically through `ansible.cfg`.
If the SSH user differs from your local username, set `ansible_user` on
`labhost` in `inventory/hosts.yml`.

## Usage

Create the lab (network first, then VMs):

```
./setup-network.sh
./setup-vms.sh
```

Tear it down (VMs first, then network):

```
./teardown-vms.sh
./teardown-network.sh
```

`teardown-vms.sh` stops each VM, undefines it, and deletes its disk and
cloud-init seed files. The downloaded base image is kept, so the next
`./setup-vms.sh` does not download it again. `teardown-network.sh` does not
check for VMs still attached to the network, so remove the VMs first.

The scripts run the playbooks with `--ask-become-pass` and pass any extra
arguments to `ansible-playbook`, for example `./setup-vms.sh --check` or
`./setup-vms.sh -v`.

All playbooks are safe to run again: existing resources are left alone.

## Configuration

Edit `inventory/group_vars/all/vars.yml`:

- `lab_network`: network name, bridge, gateway, netmask and DHCP range.
- `lab_vms`: name, MAC, IP, vCPUs, memory and disk size for each VM. The
  MAC/IP pairs become DHCP reservations on the lab network.
- `lab_image_url`, `lab_os_variant`: the base image (Debian 12 cloud image by
  default). Change both together.
- `lab_ssh_public_key_file`: public key on the control machine, authorised for
  `root` and the default `debian` user through cloud-init.

Changes to the network or VM definitions are not applied to existing
resources. Tear them down and create them again.

## Linting

```
yamllint . && ansible-lint
shellcheck *.sh
```
