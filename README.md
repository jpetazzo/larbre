# Arbre

Homelab, 2024 edition!

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

## Workloads

- VM `topeka` (home assistant)
- K8S cluster `es`
  - 3 cp nodes (2 CPU, 4 GB RAM, 50 GB)
  - 4 worker nodes (3 CPU, 16 GB RAM, 100 GB)

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

---

1) use ansible to configure hypervisors
2) use tofu to create guests
3) use ansible to configure guests
4) setup kubernetes
    - kubeadm init
    - kubeadm join
    - install CNI
    - manually patch coredns spec.template.spec.dnsConfig.nameservers[0]=1.1.1.1

common base:
- cloud init to add ssh keys
- then ansible to update ssh keys and install everything else
- all machines connected to both uplinks, using DHCP on first interface, SLAAC on both interfaces

- kansas
  - proxmox install with ZFS
  - make sure to define both bridges for both uplinks
  - set accept_ra=2 on bridges (for SLAAC)

  - topeka (Docker host)
    - ubuntu 24.04 common base
    - docker
    - containers to be started with Compose, Compose files in subdirs (ansible or not?)
  - lawrence (K8S control plane)
    - ubuntu 24.04 common base
    - kubeadm, kubelet
    - k8s workloads to be started with... Helmfile or other?
    - proxmox CSI?
  - wichita (K8S worker)
    - similar to lawrence

