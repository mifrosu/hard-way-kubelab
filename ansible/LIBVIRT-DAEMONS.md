# Libvirt daemons on the lab host

The playbooks only use the `virsh` CLI on the remote host, so the libvirt
daemons must already be running there. If they are not, `virsh` fails with:

```
error: failed to connect to the hypervisor
error: Failed to connect socket to '/var/run/libvirt/virtqemud-sock': No such file or directory
```

Run everything below on the **remote lab host**, not the control machine.

## Which daemon model?

Current Fedora uses modular, socket-activated daemons (`virtqemud`,
`virtnetworkd`, ...). Older setups use the monolithic `libvirtd`. Check which
units exist:

```
systemctl list-unit-files 'virt*.socket' 'libvirtd*.socket'
```

## Check

Modular daemons:

```
systemctl status virtqemud.socket virtnetworkd.socket virtstoraged.socket
```

Monolithic daemon:

```
systemctl status libvirtd.socket
```

Confirm `virsh` can connect:

```
sudo virsh -c qemu:///system list --all
sudo virsh -c qemu:///system net-list --all
```

## Enable

Modular daemons (Fedora default):

```
sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
```

| Socket | Needed for |
|---|---|
| `virtqemud.socket` | Connecting to the QEMU hypervisor (`qemu:///system`) |
| `virtnetworkd.socket` | Defining and starting the lab network (`site.yml`) |
| `virtstoraged.socket` | Storage pools and disk volumes (`virt-install`) |

If `virt-install` later complains about node devices, also enable
`virtnodedevd.socket`.

Monolithic daemon:

```
sudo systemctl enable --now libvirtd.socket
```

`enable --now` starts the sockets immediately and on every boot. The daemons
themselves start on demand when something connects.

## Units not found (Atomic Fedora)

The `libvirt` package is a meta-package that pulls in the daemon and the qemu,
network, nodedev and storage drivers, so layering it is enough:

```
sudo rpm-ostree install libvirt
```

Layered packages only exist in a new deployment. Until you boot into it, the
host still runs the old image, `systemctl` reports the units don't exist, and
the `virtqemud` socket is missing. Check with:

```
rpm-ostree status
```

If `libvirt` shows under `LayeredPackages` of a pending (not booted)
deployment, reboot, then run the enable step above:

```
sudo systemctl reboot
```

`sudo rpm-ostree apply-live` can make the layered packages available without a
reboot, but a reboot is the reliable route.

## Troubleshooting

- **Still can't connect after enabling:** check `journalctl -u virtqemud` and
  `journalctl -u virtnetworkd` for startup errors.
- **Permission denied:** run `virsh` with `sudo`, or use `-c qemu:///system`.
  Without a URI, `virsh` defaults to the per-user session, which has no access
  to the lab network. The playbooks set `LIBVIRT_DEFAULT_URI=qemu:///system`
  for this reason.
- **Different error from the playbook:** the network check in `site.yml` and
  `teardown.yml` only tolerates `Network not found`. Every other `virsh` error
  stops the run, so the message in the Ansible output is the real cause.
