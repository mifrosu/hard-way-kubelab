# Starting and stopping the lab VMs

Run these on the **remote lab host** with `virsh`. The VMs live in the system
libvirt instance, so either prefix commands with `sudo` or set the URI once:

```
export LIBVIRT_DEFAULT_URI=qemu:///system
```

Without it, `virsh` defaults to your per-user session and shows no VMs.

## List

```
virsh list --all        # names and states
virsh domstate node-0   # state of one VM
```

## Start

```
virsh start node-0
```

## Stop

```
virsh shutdown node-0   # graceful, like pressing the power button (ACPI)
virsh destroy node-0    # hard power-off, like pulling the plug
```

Despite its name, `destroy` does not delete anything. The VM and its disk stay
and the VM can be started again. Use it only when `shutdown` does not work.

`virsh shutdown` returns immediately. Check `virsh list --all` to see when the
VM has actually stopped.

## Other commands

```
virsh reboot node-0
virsh suspend node-0    # pause in memory
virsh resume node-0
virsh console node-0    # serial console; Ctrl+] to exit
```

## Whole lab at once

```
for vm in server node-0 node-1; do virsh shutdown "$vm"; done
for vm in server node-0 node-1; do virsh start "$vm"; done
```

## Autostart on host boot

The VMs are not set to start when the host boots. To change that for a VM:

```
virsh autostart node-0
virsh autostart --disable node-0
```

## Using the playbooks

- `./setup-vms.sh` starts any VM that exists but is shut off, and skips VMs
  that are already running.
- `./teardown-vms.sh` is **not** a way to stop VMs: it deletes them and their
  disks.
