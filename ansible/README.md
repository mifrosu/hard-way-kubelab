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
| `pki.yml` | Generate the CA and TLS certificates locally and copy them to the VMs |
| `setup-network.sh`, `setup-vms.sh`, `setup-pki.sh` | Wrappers for `site.yml`, `vms.yml` and `pki.yml` |
| `teardown-vms.sh`, `teardown-network.sh` | Wrappers for the teardown playbooks |
| `inventory/hosts.yml` | `labhost` (its IP comes from the vault) and the lab VMs |
| `inventory/group_vars/all/vars.yml` | Network, VM, image and PKI settings |
| `inventory/group_vars/all/vault.yml.example` | Template for the encrypted vault file |
| `inventory/group_vars/lab_machines/vars.yml` | How Ansible reaches the VMs (SSH through `labhost`) |
| `templates/` | libvirt network XML and cloud-init user-data |
| `files/ca.conf` | OpenSSL config used by `pki.yml`, copied from [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/52eb26dad1a3e9e8083a899bc854421eb4842a73/ca.conf); see its header for source and licensing |
| [`../docs/`](../docs) | Libvirt daemon setup and day-to-day VM management |

## Prerequisites

On the control machine: `ansible` and an SSH public key (default
`~/.ssh/id_ed25519.pub`). `pki.yml` also needs OpenSSL 3.0 or later. To run the checks in [Linting](#linting) you also
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
cloud-init seed files, then removes the VMs' saved SSH host keys. The downloaded base image is kept, so the next
`./setup-vms.sh` does not download it again. `teardown-network.sh` does not
check for VMs still attached to the network, so remove the VMs first.

Each VM keeps its cloud-init seed ISO
(`/var/lib/libvirt/images/cloud-init/<vm>-seed.iso`) attached as a read-only
disk, so don't delete those files while the VMs exist: a VM won't start
without its ISO. If they do go missing, `./setup-vms.sh` rebuilds them before
starting any VM. Changing the SSH key or cloud-init template only affects VMs
created afterwards, because cloud-init runs once per VM; recreate a VM to
apply new settings.

The network and VM scripts run the playbooks with `--ask-become-pass`. All the
scripts pass any extra arguments to `ansible-playbook`, for example
`./setup-vms.sh --check` or `./setup-vms.sh -v`.

### Certificates

Once the VMs are up, provision the CA and TLS certificates
([chapter 4](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md)
of the guide):

```
./setup-pki.sh
```

The control machine acts as the guide's jumpbox. `pki.yml` runs the guide's
`openssl` commands with `files/ca.conf` and writes the CA, keys, CSRs and
certificates to `ansible/pki/`, which is gitignored and private (mode `0700`).
It then copies the files where the guide puts them:

- `node-0`, `node-1`: `ca.crt`, plus the node's key pair as
  `/var/lib/kubelet/kubelet.crt` and `kubelet.key`.
- `server`: `ca.key`, `ca.crt`, and the `kube-api-server` and
  `service-accounts` key pairs, in `/root/`.

The other certificates stay in `ansible/pki/` for the next chapter of the
guide (kubeconfig files).

Existing files in `ansible/pki/` are never regenerated, so running it again
only re-copies them. Delete `ansible/pki/` to start over with a new CA. Run
either half on its own with `./setup-pki.sh --tags generate` or
`./setup-pki.sh --tags distribute`.

`ca.conf` names the VMs (`node-0`, `node-1`) and the `kubernetes.local`
domain, so update it if you change `lab_vms` or `lab_domain`.

### Connecting to the VMs

Ansible reaches the VMs as `root` with SSH `ProxyJump` through `labhost`. On
first connection, each VM's host key is accepted and saved in
`ansible/.lab_known_hosts` (gitignored), separate from `~/.ssh/known_hosts`.
`teardown-vms.sh` removes the saved keys, so the new keys of recreated VMs are
accepted. `labhost` itself is still checked strictly against
`~/.ssh/known_hosts`.

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
- `lab_domain`: DNS domain for the VMs' FQDNs (`kubernetes.local`).
- `lab_pki_dir`: where `pki.yml` writes the CA and certificates on the control
  machine (default `ansible/pki/`).

If you add, remove or rename VMs in `lab_vms`, update `inventory/hosts.yml` to
match.

Changes to the network or VM definitions are not applied to existing
resources. Tear them down and create them again.

## Linting

```
yamllint . && ansible-lint
shellcheck *.sh
```
