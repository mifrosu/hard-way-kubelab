# Hard-way Kubelab

A lab for working through
[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
on virtual machines running on a remote libvirt host.

## Lab layout

A NAT network (`k8s`, `10.100.0.0/24`) with three Debian VMs:

| VM | IP |
|---|---|
| `server` | 10.100.0.10 |
| `node-0` | 10.100.0.20 |
| `node-1` | 10.100.0.21 |

## Contents

- [`ansible/`](ansible/README.md): playbooks and scripts that create and tear
  down the lab network and VMs on the remote host.
- [`docs/`](docs): guides for the remote host.
  - [LIBVIRT-DAEMONS.md](docs/LIBVIRT-DAEMONS.md): checking and enabling the
    libvirt daemons.
  - [MANAGING-VMS.md](docs/MANAGING-VMS.md): starting and stopping the VMs.

## Quick start

```
cd ansible
./setup-network.sh
./setup-vms.sh
```

See the [ansible README](ansible/README.md) for prerequisites, vault setup and
configuration.
