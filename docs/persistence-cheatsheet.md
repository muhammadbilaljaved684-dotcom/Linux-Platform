# Persistence cheat sheet – what makes a change survive a reboot

← Back to the [README](../README.md)

💡 **In plain words:** a command like `ip addr add`, `mount` or `iptables -A` changes the running system **only until the next reboot**. To keep a change, write it into the right **config file** – or `enable` the service – and **test before rebooting**.

## The files used in this project

| File / command | Server | What it does |
|---|---|---|
| `/etc/netplan/*.yaml` | all | Fixed IP addresses that survive reboots – test with `netplan try` |
| `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` | all | Stops cloud-init from overwriting the network settings |
| `/etc/sysctl.d/99-forward.conf` (`net.ipv4.ip_forward=1`) | gw01 | gw01 stays a router after a reboot |
| `iptables-persistent` → `/etc/iptables/rules.v4` (`netfilter-persistent save`) | gw01 | NAT and firewall rules restored at boot |
| `systemctl set-default multi-user.target` | gw01 | Boot into server mode, no desktop |
| `/etc/hosts` | all | Names → IP addresses, so servers find each other by name |
| `~/.ssh/authorized_keys` | each server | Accepts gw01's key – login without a password |
| `~/.ssh/config` | gw01 | SSH nicknames: `ssh svc01` instead of user@address |
| `/etc/ssh/sshd_config` | each server | The SSH **server's** own rules (key or password login …) |
| `systemctl enable --now <service>` | all | Start a service now **and** at every boot (docker, glpi-agent, nfs-server) |
| `restart: unless-stopped` in `compose.yaml` | svc01 | GLPI and MySQL start again after a crash or reboot |
| `/etc/glpi-agent/conf.d/00-install.cfg` | all | Where the agent sends its inventory (`server = http://192.168.60.40/`) |
| `/etc/exports` + `exportfs -ra` | stor01 | Which folders NFS shares, with whom, with what rights |
| `/etc/fstab` – test with `mount -a` | stor01, app01 | What to mount at every boot: LVM volumes by UUID, the NFS share (`_netdev,nofail`) |

## The habit

1. **Back up** the file first: `sudo cp /etc/fstab /etc/fstab.bak`
2. **Change** it.
3. **Test without rebooting**: `netplan try`, `mount -a`, `exportfs -ra`, `systemctl status`.
4. Only then reboot – a mistake found now costs a minute; found at boot, it can take the server down (Day 4: one wrong UUID character in fstab).
