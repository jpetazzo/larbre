# Arbre

Homelab, 2026 edition!

## Networking

Subnets:

| Name | Subnet         |
|------|----------------|
| AT&T | 192.168.1.0/24 |
| Cox  | 192.168.2.0/25 |
| LAN  | TBD            |

Hosts, IPv4:

| Prefix    | Host    | Usage    |
|-----------|---------|----------|
| 192.168.X | 1       | gateway  |
| 192.168.X.| 2-10    | reserved |
| 192.168.X.| 11-99   | DHCP     |
| 192.168.X.| 100     | reserved |
| 192.168.X.| 101-199 | VMs      |
| 192.168.X.| 200     | reserved |
| 192.168.X.| 201-249 | HVs      |
| 192.168.X.| 250-254 | reserved |

Hosts, IPv6:

| Prefix  | Host                | Usage      |
|---------|---------------------|------------|
| x:x:x:x | xxxx:xxff:fexx:xxxx | SLAAC      |
| x:x:x:x | 0000:0000:0000:xxxx | DHCP6      |
| x:x:x:x | 01xx:0000:0000:0001 | VMs        |
| x:x:x:x | 01xx::/80           | VM subnets |
| x:x:x:x | 02xx:0000:0000:0001 | HVs        |
| x:x:x:x | 02xx::/80           | HV subnets |

E.g.: VM #105 has:
- 192.168.1.105
- 192.168.2.105
- (ipv6prefix):105::1
- (ipv6prefix):105::/80

❓ Decide if LAN will be in 192.168.0 or 10.0.0.0/24?

## Hardware

| host     | #   | CPU   | RAM   | NVMe | SATA |
|----------|-----|-------|-------|------|------|
| kansas   | 201 | N100  | 32 GB | 1 TB | 2 TB |
| colorado | 202 | N100  | 48 GB | 2 TB | 2 TB |
| oregon   | 203 | N6000 | 64 GB | 2 TB | 2 TB |

## Hypervisor installation

From Proxmox USB media. ZFS rootfs. Join the PVE cluster.

First disk (NVMe) is used for ZFS pool.

Second disk (SATA or NVMe depending on what's available) is used for Ceph OSD.

Network interfaces are enp2s0 to enp5s0.

Three bridges are configured:
- vmbr0 (enp2s0) = LAN
- vmbr1 (enp3s0) = AT&T
- vmbr2 (enp4s0) = Cox

enp5s0 can be added to any of the bridges for convenience (until we get a proper
switch; then perhaps we can do bonding with the LAN interface, or add a dedicated
subnet for Ceph traffic or whatever).

See `interfaces` file.

## Workloads

| VM       | #   |
| spv      | 105 |
| haos13.2 | 106 |

## Deployment

### Deployment (control) machine

Use ansible version 2.16 or above to be compatible with Python 3.12 on the target nodes!

(If using proxmox host as the control node, use pipx to install Ansible: pipx install ansible-core)

### Target machines

On the hypervisors, install `sudo`.

Install your SSH key so that you can `ssh root@X` on each hypervisor.

### Ansible cheatsheet

From the `ansible` subdirectory:

```
ansible-playbook -i inventory/ hypervisors.yml
```


- kansas
  - proxmox install with ZFS
  - make sure to define both bridges for both uplinks
  - set accept_ra=2 on bridges (for SLAAC)


## Misc events

2026-04-08 swapped out failed disk 1F2410070030098 on oregon
