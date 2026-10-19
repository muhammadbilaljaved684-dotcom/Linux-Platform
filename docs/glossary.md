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
| **User / group** | An account for one person / a team of accounts that share rights | `useradd`, `groupadd`, `id`, `getent group` |
| **Primary / secondary group** | Your own default group / extra teams you belong to | `gid=` / `groups=` in `id` |
| **Service account** | An account for a program, not a person – low rights, nobody logs in | `useradd -r -s /usr/sbin/nologin`; uid < 1000 |
| **nologin** | A "shell" that refuses every login | `/usr/sbin/nologin` |
| **Least privilege** | Give every person and program only the rights it needs | Normal user + `sudo` when needed |
| **Password aging** | Rules for when a password expires | `chage -l`, `chage -M 90` |
| **Lock / unlock** | Switch an account off (leaver) and on again | `usermod -L` / `-U`, status with `passwd -S` |
| **Switch** | An extension board for a network: devices plugged in talk directly | VMnet2, VMnet8 are virtual switches |
| **Host adapter** | A virtual network card on the Windows PC for one VMnet switch | Tick "Connect a host virtual adapter" |
| **Network adapter / NIC** | The network card of a machine | `ens33`, `ens34` in Linux |
| **VMnet2 / VMnet8** | Virtual network switches inside VMware | VMnet8 = NAT to the internet; VMnet2 = isolated lab |

## Phase 1A – the service desk

| Term | Plain words | Technical |
|---|---|---|
| **Service desk / ticket system** | The place where every problem and request is recorded and tracked | GLPI (free), like ServiceNow or Freshservice |
| **Incident** | Something broke and must be fixed | Ticket type in ITIL |
| **Change** | A planned change, with a plan and a way back | Change ticket with rollback |
| **Request** | Someone asks for something (access, software) | Service request |
| **Knowledge base (KB)** | Written fixes so the next person solves it faster | KB articles |
| **Asset inventory / CMDB** | A list of every machine and what is on it | Filled automatically by the GLPI agent |
| **SLA** | The promised time to answer or fix | Service Level Agreement |
| **Time to own / time to resolve** | How fast a technician must take a ticket / fix it | High: 1 h / 8 h in the Acme SLA |
| **CSRF token** | One-time security code inside a web form; an old form stops working | Fix: open the page fresh |
| **restart: unless-stopped** | Docker starts the container again after a crash or reboot | In `compose.yaml` |
| **L1 / L2 / L3** | Support levels: service desk → technical admins → experts/vendor | Ticket moves up only if the lower level cannot solve it |
| **Escalation** | Passing a ticket to a higher level, with notes | Reassign to a higher group in GLPI |
| **Dropdown (GLPI)** | A list of allowed values, such as statuses and locations | Setup → Dropdowns → Common |
| **Mass update** | Change one field on many items at once | Tick items → Actions → Update |
| **Inventory authentication** | Proof an agent must send before GLPI accepts its report | None in the lab; Basic Authentication in Phase 6 |
| **GLPI agent** | Small program on each server that reports its hardware and software | Not a person; creates no tickets |
| **VPN** | A secure tunnel that puts a remote laptop "inside" the company network | WireGuard on gw01 (Phase 6A) |
| **Docker Compose** | One file that describes several containers and starts them together | `compose.yaml`, `docker compose up -d` |
| **.env file** | Settings and passwords for the containers, kept out of the main file | `chmod 600` – only root may read |
| **HTTP status code** | The 3-digit answer of a web server | 200 OK · 404 not found · 500 server error |
| **ITIL** | The common rule book for running IT services | IT Infrastructure Library |

## Storage (coming in Phase 2)

| Term | Plain words | Technical |
|---|---|---|
| **Inode** | A file's ID card: owner, permissions, size, dates, where the data is – but not the name | Number shown by `ls -i`, `stat`; capacity by `df -i` |
| **Hard link** | A second name for the same file | `ln a b` – same inode, link count +1 |
| **Soft (symbolic) link** | A signpost to another file's name; breaks if that name is deleted | `ln -s a b` – own inode, stores a path |
| **Link count** | How many names a file has; data is freed when it reaches 0 | Third column of `ls -l` |
| **Disk / block device** | A storage drive | `sda` (system), `sdb`, `sdc` (data); listed by `lsblk` |
| **Partition** | A section of a disk | `sda1`, `sda2`, … |
| **/etc/fstab** | The list of what to mount at every boot | Test with `mount -a` before a reboot |
| **UUID** | Permanent ID of a volume, never changes | `blkid` shows it |
| **Extent** | The 4 MB blocks LVM hands out | 3 GiB = 768 extents |
| **NFS** | Network File System: use another server's folder over the network | stor01 `/data/app` → app01 `/mnt/app` |
| **/etc/exports** | NFS server's list of shared folders and who may use them | `exportfs -ra` applies it |
| **root_squash** | NFS treats a client's root as "nobody" | Files arrive owned by `nobody` |
| **_netdev / nofail** | fstab options for network disks: wait for the network / boot anyway if it is missing | app01 NFS line |
| **tar archive** | Many files packed into one (compressed) file | `tar -czf` create · `-tzf` list · `-xzf` extract |
| **rsync** | Smart copy: only what changed; keeps owners and permissions | `rsync -avh --delete src/ dst/` |
| **Mirror** | A folder kept identical to the original – no history | `/backups/mirror` |
| **--link-dest** | rsync compares with a previous backup and hard-links unchanged files | Versions with history for the space of the changes |
| **Restore drill** | Deliberately restoring a "lost" file to prove backups work | Done through a GLPI Request ticket |
| **PV / VG / LV** | Disk space handed to LVM / the pool / a slice of the pool used as a drive | `pvs`, `vgs`, `lvs`; grow with `lvextend -r` |
| **Mount** | Make a formatted volume usable at a folder | `/` on Linux; a drive letter on Windows |
| **Docker image / container** | The installer / the running program made from it | `docker images`, `docker ps` |
| **Mounted folder (Docker volume)** | A host folder shown inside a container, where it keeps its data | Survives when the container is replaced |
| **Storage Spaces / Storage Pool** | Windows version of LVM: disks → pool → virtual disks | Server Manager → File and Storage Services |
| **LVM** | Lets you combine disks into one pool and grow storage later without downtime | Logical Volume Manager: PV → VG → LV |
