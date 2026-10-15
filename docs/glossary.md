# Glossary – plain-language explanations

Terms used in the progress reports, explained for readers without a Linux background. Grouped by topic, in the order they appear in the project.

## The basics

| Term | Plain words | Technical |
|---|---|---|
| **Virtual machine (VM)** | A computer simulated by software, running inside a real computer | A guest OS on virtual hardware provided by a hypervisor |
| **Hypervisor** | The software that runs virtual machines | Here: VMware Workstation on Windows |
| **Server** | A computer that provides a service to others (website, files, …) and usually has no screen or user sitting at it | |
| **Ubuntu Server** | A free Linux operating system made for servers | Ubuntu 22.04 LTS ("long-term support", updates until 2027+) |
| **Terminal / shell / console** | The text window where you type commands | bash shell in the VMware console |
| **`sudo`** | "Do this as administrator" – asks for your password | Runs a command as root (super-user) |
| **Snapshot** | A saved "photo" of a VM you can return to if something breaks | VMware snapshot of disk and settings |

## Phase 0 – the system

| Term | Plain words | Technical |
|---|---|---|
| **Kernel** | The engine of Linux; talks to the hardware | Linux 5.15.0-198-generic |
| **Module / driver** | An add-on that lets the kernel use a specific piece of hardware | Loadable kernel module, listed with `lsmod` |
| **Swap** | Disk space used as emergency memory when RAM is full | Swap file/partition |
| **Boot** | The start-up sequence of a computer | firmware → GRUB → kernel → initramfs → systemd |
| **GRUB** | The program that picks and loads the operating system at start | Bootloader |
| **systemd** | The "manager" that starts and supervises all services | Init system, PID 1 |
| **Service** | A program running in the background (e.g. SSH, web server) | systemd unit |
| **Target** | A start-up "mode" – desktop or server | `graphical.target` vs `multi-user.target` |
| **Baseline** | A record of how the system looked before changes | Reference for troubleshooting and audits |

## Phase 1 – the network

| Term | Plain words | Technical |
|---|---|---|
| **IP address** | A machine's "phone number" on a network | e.g. 192.168.60.10 |
| **Private address** | A number valid only inside a home/company network, not on the internet | RFC 1918 ranges, e.g. 192.168.x.x |
| **Public address** | The number the internet sees for your whole home or company | Assigned by the internet provider |
| **`/24`** | Size of the network: the first three number blocks are the same for everyone in it | Subnet mask 255.255.255.0 → 256 addresses |
| **Network card / interface** | The "socket" a network cable plugs into | `ens33`, `ens34`; `lo` = loopback (talking to itself) |
| **DHCP** | A service that hands out addresses automatically | Dynamic Host Configuration Protocol |
| **Static IP** | An address set by hand that never changes | Configured in netplan |
| **netplan** | Ubuntu's tool for network settings, written in a text file | YAML in `/etc/netplan/` |
| **YAML** | A text format where indentation (spaces) carries meaning | Used by netplan, Ansible, Docker Compose |
| **cloud-init** | A helper that configures a fresh server at first boot – and may overwrite manual settings | Disabled for networking in `/etc/cloud/cloud.cfg.d/` |
| **Gateway / default route** | "Where do I send traffic for places I don't know?" – the exit door | `default via 192.168.60.1` |
| **Routing table** | The list of rules for where traffic goes | `ip route` |
| **Router** | A machine that passes traffic between networks | gw01 after `ip_forward = 1` |
| **IP forwarding** | The switch that lets Linux act as a router | `net.ipv4.ip_forward` |
| **sysctl** | Tool to read/change kernel settings | Persistent settings in `/etc/sysctl.d/` |
| **NAT** | Like a company mailroom: replaces the sender address on outgoing mail with the company address and delivers replies to the right person | Network Address Translation |
| **MASQUERADE** | NAT that automatically uses the gateway's current address | iptables target for source NAT on dynamic addresses |
| **SNAT / DNAT** | Outgoing address rewrite to a fixed address / incoming "port forwarding" to an inside server | iptables targets (DNAT is used in Phase 7) |
| **Firewall** | A guard that decides which traffic may pass | iptables / UFW rules |
| **iptables** | The classic Linux firewall tool | Tables `nat`, `filter`; chains `POSTROUTING`, `FORWARD` |
| **Stateful rule** | "Only let in replies to conversations we started" | `--state ESTABLISHED,RELATED` |
| **TTL** | A counter in each packet that drops by 1 at every router – shows how many routers were passed | Time To Live |
| **ping** | "Are you there?" – sends a small test message and waits for a reply | ICMP echo |
| **curl** | Fetches a web page from the command line | HTTP client |
| **DNS** | The internet's phone book: turns names into IP addresses | Domain Name System |
| **`/etc/hosts`** | A small personal contact list of names → addresses on one machine | Checked before DNS |
| **nsswitch.conf** | Decides the **order** in which Linux looks up names | `hosts: files dns` |
| **`getent`** | "Get entry" – asks the system what a name resolves to, the same way programs do | Uses the nsswitch order |
| **dig** | A tool to ask DNS directly | Part of `dnsutils` |
| **SSH** | Secure remote login to a server's terminal over the network | OpenSSH, port 22 |
| **Port** | A numbered "door" on a machine for a specific service | e.g. 22 = SSH, 53 = DNS, 80 = web |
| **Socket** | A program standing at a door: address + port + protocol | e.g. `127.0.0.53:53` (TCP) |
| **TCP / UDP** | Phone call (confirmed, reliable) / postcard (just sent) | TCP: 3-way handshake SYN, SYN-ACK, ACK |
| **LISTEN / UNCONN / ESTAB** | Door waiting / UDP door open / conversation running | States shown by `ss` |
| **ss** | Shows which program waits behind which door | `ss -tulpn` = socket statistics |
| **netcat (nc)** | Knocks on a port to test whether a service answers | `nc -zv app01 22` |
| **Loopback** | The machine talking to itself – every 127.x.x.x address | 127.0.0.1 localhost, 127.0.1.1 own name, 127.0.0.53 DNS helper |
| **Binding address** | Which address a service listens on | `0.0.0.0` = all addresses; `127.0.0.53` = one address only |
| **Refused vs timeout** | "Nobody here" vs no answer at all | Refused = service problem; timeout = network/firewall |
| **File descriptor (fd)** | The number a program uses for something it has open | fd 13, fd 14 in `ss` output |
| **VMnet2 / VMnet8** | Virtual network switches inside VMware | VMnet8 = NAT to the internet; VMnet2 = isolated lab |

## Storage (coming in Phase 2)

| Term | Plain words | Technical |
|---|---|---|
| **Inode** | A file's ID card: owner, permissions, size, dates, where the data is – but not the name | Number shown by `ls -i`, `stat`; capacity by `df -i` |
| **Hard link** | A second name for the same file | `ln a b` – same inode, link count +1 |
| **Soft (symbolic) link** | A signpost to another file's name; breaks if that name is deleted | `ln -s a b` – own inode, stores a path |
| **Link count** | How many names a file has; data is freed when it reaches 0 | Third column of `ls -l` |
| **Disk / block device** | A storage drive | `sda` (system), `sdb`, `sdc` (data); listed by `lsblk` |
| **Partition** | A section of a disk | `sda1`, `sda2`, … |
| **LVM** | Lets you combine disks into one pool and grow storage later without downtime | Logical Volume Manager: PV → VG → LV |
