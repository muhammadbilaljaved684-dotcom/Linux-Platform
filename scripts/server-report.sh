#!/bin/bash
# server-report.sh – a full "check-up" of one Linux server, saved in one file.
# Read-only: it only looks, it changes nothing. Run it with sudo on any server:
#   sudo bash server-report.sh
# Output: one text file, saved in two places:
#   /var/tmp/server-report-<host>-<date>.txt
#   ~/server-reports/server-report-<host>-<date>.txt   (in the home folder of the user who ran sudo)
# Every block in the file explains itself: ABOUT = what this block checks,
# GOOD = what a healthy answer looks like, BAD = what a problem looks like and what to do.
# Project 2 – Acme Analytics Linux platform
#
# Grows with the project – a role section is added when a phase adds a service:
#   Phase 5  rsyslog central logs ✔ · journal size · logrotate
#   Phase 5A monitoring: node_exporter / Prometheus / Grafana up, alert rules
#   Phase 6  security: fail2ban jails, auditd rules, AppArmor profiles, forward proxy (Squid)
#   Phase 6A WireGuard VPN: wg show, peers and last handshake
#   Phase 6B Greenbone: services/containers up, last scan
#   Phase 7  nginx reverse proxy + load balancer upstreams, TLS certificate expiry date, DNS (dig)
#   Phase 7B SuiteCRM: web app answers, its database, backup age

HOST=$(hostname)
STAMP=$(date +%Y-%m-%d_%H%M)
OUT="/var/tmp/server-report-${HOST}-${STAMP}.txt"
WARN=()

has() { command -v "$1" >/dev/null 2>&1; }
active() { systemctl is-active --quiet "$1" 2>/dev/null; }
sec() { printf '\n==================== %s ====================\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
warn() { WARN+=("$1"); }
# about = what the block checks · good/bad = how to read the answer of the command above
about() { printf 'ABOUT: %s\n' "$*"; }
good()  { printf '   GOOD: %s\n' "$*"; }
bad()   { printf '   BAD:  %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo:  sudo bash $0"; exit 1
fi

KERNEL_WORDS="out of memory|oom|killed process|soft lockup|stuck|hung_task|blocked for more than|i/o error|ext4-fs error|read-only|link is down|reset adapter|timed out|segfault|call trace|conntrack.*full|throttl"

# ---------- quick checks for the summary ----------
CPUS=$(nproc)
LOAD=$(cut -d' ' -f1 /proc/loadavg)
awk -v l="$LOAD" -v c="$CPUS" 'BEGIN{exit !(l>c)}' && warn "Load $LOAD is higher than the $CPUS CPUs – the CPU is busy (block 2)"

MEM_AVAIL_PCT=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", a*100/t}' /proc/meminfo)
[ "$MEM_AVAIL_PCT" -lt 10 ] && warn "Only ${MEM_AVAIL_PCT}% RAM available (block 2)"
SWAP_USED=$(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print t-f}' /proc/meminfo)
[ "$SWAP_USED" -gt 102400 ] && warn "Swap in use: $((SWAP_USED/1024)) MB – RAM was short at some point (block 2)"

while read -r use mnt; do
  p=${use%\%}; [ "$p" -ge 85 ] 2>/dev/null && warn "Disk $mnt is ${use} full (block 3)"
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1{print $5, $6}')
while read -r use mnt; do
  p=${use%\%}; [ "$p" -ge 85 ] 2>/dev/null && warn "Inodes on $mnt are ${use} used (block 3)"
done < <(df -P -i -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 && $5!="-"{print $5, $6}')

FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | xargs)
[ -n "$FAILED" ] && warn "Failed services: $FAILED (block 5)"

KPROB=$(journalctl -k -b -p warning --no-pager 2>/dev/null | grep -i -c -E "$KERNEL_WORDS")
[ "$KPROB" -gt 0 ] && warn "Kernel log (this run): $KPROB problem line(s) – see block 6"
ERR24=$(journalctl -p err --since "24 hours ago" --no-pager -q 2>/dev/null | wc -l)
[ "$ERR24" -gt 0 ] && warn "$ERR24 error line(s) in the journal in the last 24 hours (block 7)"

if has lsof; then
  DELOPEN=$(lsof -nP +L1 2>/dev/null | awk 'NR>1' | wc -l)
  [ "$DELOPEN" -gt 0 ] && warn "$DELOPEN deleted file(s) still open (space not freed) – check: sudo lsof +L1, then restart that program (Phase 4)"
fi
[ -f /var/run/reboot-required ] && warn "A reboot is required (updates) (block 10)"
if has timedatectl; then
  timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes || warn "Clock is not synchronised (NTP) (block 1)"
fi
if has apt; then
  UPG=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
  [ "$UPG" -gt 0 ] && warn "$UPG package update(s) waiting (block 10)"
fi

# ---------- what this server is ----------
ROLES=()
active nginx && ROLES+=("web server (nginx)")
active apache2 && ROLES+=("web server (apache)")
ls /etc/postgresql >/dev/null 2>&1 && ROLES+=("database (PostgreSQL)")
active nfs-server && ROLES+=("NFS server")
grep -qs "imtcp\|imudp" /etc/rsyslog.d/*.conf && ROLES+=("central log server (rsyslog receives)")
grep -qs "omfwd\|@@" /etc/rsyslog.d/*.conf && ROLES+=("sends logs to a log server")
[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ] && ROLES+=("router / gateway (ip_forward on)")
[ ${#ROLES[@]} -eq 0 ] && ROLES+=("general server")

{
echo "SERVER REPORT – $HOST – $(date '+%Y-%m-%d %H:%M %Z')"
R=$(printf '%s, ' "${ROLES[@]}"); echo "Roles found: ${R%, }"
echo
echo "HOW TO READ THIS FILE"
echo "  1. Read the SUMMARY first. 'OK' = nothing found. Each WARN line = one thing to check."
echo "  2. Go to the block the WARN line talks about. Every block starts with ABOUT (what it checks)."
echo "  3. Under every command: GOOD = a healthy answer, BAD = a problem and the next step."
echo "  4. Lines starting with \$ are the command that was run; the lines under it are its answer."

sec "SUMMARY"
about "The short result. Every WARN line points to a block below."
if [ ${#WARN[@]} -eq 0 ]; then
  echo "OK – no warnings found."
else
  for w in "${WARN[@]}"; do echo "WARN  $w"; done
fi
echo "Load: $LOAD on $CPUS CPUs · RAM available: ${MEM_AVAIL_PCT}% · kernel problem lines: $KPROB · errors 24h: $ERR24"

sec "1 SYSTEM"
about "Which server is this, how long has it been running, did it restart, is the clock right?"
run "hostnamectl 2>/dev/null | grep -E 'Static hostname|Operating System|Kernel|Virtualization'"
good "The name is the server you wanted (app01, db01 ...). OS Ubuntu, Virtualization: vmware."
bad  "Another name = you are on the wrong server. Stop and log in to the right one."
run "uptime"
good "'up 3 days' (or as long as you expect). The 3 load numbers are lower than the CPU count."
bad  "'up 5 min' when nobody restarted it = an unplanned restart (crash, power, update). Check block 6 (kernel) with -b -1."
bad  "Load higher than the CPU count = the CPU is busy or programs wait for the disk. See block 2."
run "last -x reboot shutdown 2>/dev/null | head -5"
good "Every 'reboot' line has a 'shutdown' line just under it = a clean, planned restart."
bad  "A 'reboot' with no 'shutdown' before it = the server went down hard (crash, power off, VM paused)."
run "journalctl --list-boots --no-pager | tail -3"
good "0 = this run, -1 = the run before. Use it with: journalctl -b -1 (the log of the run before)."
bad  "Many boots in a short time = the server keeps restarting."
run "timedatectl 2>/dev/null | grep -E 'Local time|synchronized|Time zone'"
good "System clock synchronized: yes. Time zone is the right one."
bad  "synchronized: no = log times are wrong, comparing logs between servers gets confusing. Check: systemctl status systemd-timesyncd"

sec "2 CPU AND MEMORY"
about "Is the CPU busy, is RAM full, is the server swapping, which program uses the most?"
run "lscpu | grep -E 'Model name|^CPU\(s\)'"
good "CPU(s) = how many CPUs. Remember this number for the load and the 'r' column."
run "free -h"
good "'available' (RAM line) is big, e.g. 1.2Gi of 1.9Gi. 'buff/cache' big is fine – that is the page cache (Day 15)."
bad  "'available' under 10% of 'total' = RAM is short. Swap 'used' growing = RAM was full. Look at the memory list below."
run "vmstat 1 3"
good "r (waiting for CPU) not higher than the CPU count · b = 0 · si/so = 0 · wa under 10 · id high (e.g. 90)."
bad  "b > 0 and wa high = programs wait for the disk (like Lena's dsync case). si/so > 0 = swapping now, RAM is full."
bad  "r higher than the CPU count and id near 0 = the CPU is fully busy. Find the program in the next list."
run "ps -eo pid,user,%cpu,%mem,stat,cmd --sort=-%cpu | head -6"
good "The top programs use little %CPU, or the busy one is expected (e.g. backup at night)."
bad  "One program at 90–100% CPU for a long time = it loops or is overloaded. Note PID + name, check its log."
run "ps -eo pid,user,%cpu,%mem,stat,cmd --sort=-%mem | head -6"
good "postgres / nginx near the top is normal on db01 / app01."
bad  "One program with a very high %MEM that keeps growing = memory leak. Limit it (MemoryMax=) or restart it."
run "ps -eo pid,stat,cmd | awk '\$2 ~ /^D/'"
good "Empty (only the header line) = no program is stuck waiting for the disk."
bad  "Lines with STAT D = programs stuck waiting for the disk or the NFS share. Check block 3 (iostat, NFS)."

sec "3 DISKS"
about "Is a disk full, are the inodes full, is the NFS share mounted, is the disk slow?"
run "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT"
good "All disks you expect are there with a MOUNTPOINT (e.g. sda, /, and on stor01 the data disk)."
bad  "A disk without a MOUNTPOINT that should have one = it was not mounted (check /etc/fstab, mount -a)."
run "df -h -x tmpfs -x devtmpfs -x squashfs"
good "Use% under 85% everywhere."
bad  "85% or more = clean up soon. 100% = programs cannot write (logs, uploads, DB fail). Find big files: sudo du -xh / | sort -h | tail"
run "df -i -x tmpfs -x devtmpfs -x squashfs"
good "IUse% under 85%."
bad  "IUse% 100% = no new files possible even with free space (millions of tiny files). Find the folder with most files."
run "findmnt -t nfs,nfs4 2>/dev/null"
good "On app01: the stor01 share is listed. On other servers: empty is normal."
bad  "Empty on a server that should have the share = not mounted. Try: sudo mount -a, check stor01 is on."
has iostat && run "iostat -xz 1 2 | tail -n +4"
has iostat && good "%util under 70, r_await / w_await small (under ~20 ms)."
has iostat && bad  "%util near 100 and a big await = the disk is the slow part. Find who writes: sudo iotop"

sec "4 NETWORK"
about "Does the server have its IP, can it reach the gateway, does it know the names, which ports are open?"
run "ip -br a"
good "ens33 UP with 192.168.60.x/24 (the right IP for this server)."
bad  "DOWN or no IP = network not up. Check: sudo netplan apply, the VM network (VMnet2) in VMware."
run "ip route"
good "'default via 192.168.60.1' (gw01) is there."
bad  "No 'default' line = the server cannot reach anything outside 192.168.60.0/24 (no updates, no internet)."
run "resolvectl dns 2>/dev/null || cat /etc/resolv.conf"
good "A DNS server is listed."
bad  "Empty = names on the internet do not work (apt update fails with 'Temporary failure resolving')."
run "grep -v '^#' /etc/hosts | grep -v '^\$'"
good "All lab servers are listed: gw01 .1, app01 .10, stor01 .20, db01 .30, svc01 .40."
bad  "A server missing = 'ping db01' fails with 'Name or service not known'. Add the line."
run "ss -tlnp"
good "The ports this server should have: 22 sshd everywhere, 80 nginx (app01), 5432 postgres (db01), 514 rsyslog (stor01), 2049 NFS (stor01)."
bad  "An expected port missing = that service is not running (see block 5). An unknown port = find the program in the last column."
run "ss -s | head -3"
good "A few connections (estab) – a small lab has tens, not thousands."
bad  "Thousands of connections or 'timewait' = too much traffic or an app that does not close connections."

sec "5 SERVICES"
about "Did any service fail, what runs, when do the timers (backup, updates) run?"
run "systemctl --failed --no-pager"
good "'0 loaded units listed.'"
bad  "A unit listed = it failed. Next: systemctl status <name> and journalctl -u <name> -n 30"
run "systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print \$1}'"
good "The services you expect for this server are in the list (nginx, postgresql@14-main, rsyslog, ssh ...)."
bad  "An expected service missing = it is stopped. Start it: sudo systemctl start <name>"
run "systemctl list-timers --no-pager | head -12"
good "NEXT and LAST have times; your backup timer is listed with a LAST time from last night."
bad  "LAST says 'n/a' for the backup = it never ran. Check: journalctl -u <backup>.service"

sec "6 KERNEL (problem words)"
about "Did the kernel (the core of Linux) report a problem? This catches freezes, RAM full, disk and network errors."
echo "Words searched: $KERNEL_WORDS"
run "journalctl -k -b -p warning --no-pager | grep -i -E \"$KERNEL_WORDS\" | tail -30"
echo "--- run before (-b -1) ---"
run "journalctl -k -b -1 -p warning --no-pager 2>/dev/null | grep -i -E \"$KERNEL_WORDS\" | tail -15"
good "Empty = the kernel reported none of these problems."
bad  "oom / killed process = RAM was full, the kernel killed a program (name is in the line)."
bad  "soft lockup / CPU stuck = the CPU did not answer for seconds (VM paused, host overloaded – ticket #9)."
bad  "hung_task / blocked for more than = a program waited too long for the disk or NFS."
bad  "I/O error / EXT4-fs error / read-only = the disk has problems; Linux may set it read-only. Back up data now."
bad  "Link is down / Reset adapter = the network card lost its link. timed out = something did not answer."
bad  "segfault / call trace = a program (or the kernel) crashed. throttl = the CPU slowed down (heat or limit)."

sec "7 ERRORS (last 24 hours)"
about "All error lines from all services in the last 24 hours."
run "journalctl -p err --since '24 hours ago' --no-pager -q | tail -30"
good "Empty, or a few lines you already know (e.g. your own logger test lines from Step 5.2)."
bad  "The same line again and again from one service = that service has a real problem. Next: journalctl -u <service> -n 50"

sec "8 USERS AND LOGINS"
about "Who is logged in now, who logged in lately, who can use sudo?"
run "who"
good "Only you (and your own other sessions)."
bad  "A user or an IP you do not know = someone else is on the server. Check block 9 and auth.log."
run "last -n 8 | head -8"
good "Your own logins from gw01 (192.168.60.1) or your own laptop."
bad  "Logins at strange times or from unknown IPs."
run "getent group sudo"
good "Only the admin users you created (e.g. bilal_002 on app01)."
bad  "An unknown user in the sudo group = that user can do everything. Remove: sudo gpasswd -d <user> sudo"

sec "9 SECURITY"
about "Is the firewall on, how is SSH set up, is AppArmor on, are there many failed logins?"
has ufw && run "ufw status"
has ufw && good "Status: active, with only the ports this server needs. (inactive is OK until Phase 6.)"
has ufw && bad  "Port open to 'Anywhere' that should only be open to one server (e.g. 5432 only for app01)."
run "sshd -T 2>/dev/null | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '"
good "permitrootlogin no · pubkeyauthentication yes · passwordauthentication no (the target for Phase 6)."
bad  "permitrootlogin yes = root can log in over SSH. passwordauthentication yes = passwords can be guessed."
has aa-status && run "aa-status 2>/dev/null | head -3"
has aa-status && good "'apparmor module is loaded' and some profiles in enforce mode."
has aa-status && bad  "'module is not loaded' = AppArmor is off."
[ -f /var/log/auth.log ] && run "grep -c 'Failed password' /var/log/auth.log"
[ -f /var/log/auth.log ] && good "0 or a small number (your own typos)."
[ -f /var/log/auth.log ] && bad  "Hundreds or more = someone is guessing passwords. Phase 6: fail2ban blocks them."

sec "10 UPDATES"
about "Are updates waiting, does the server need a restart?"
has apt && run "apt list --upgradable 2>/dev/null | head -15"
good "Only 'Listing... Done' = everything is up to date."
bad  "Many lines, especially with '-security' = install soon: sudo apt update && sudo apt upgrade"
[ -f /var/run/reboot-required ] && echo "BAD:  /var/run/reboot-required exists = a restart is needed to finish updates. Plan it."

# ---------- role sections ----------
if active nginx || has nginx; then
  sec "ROLE: NGINX (web server)"
  about "Does the web server run, is its config correct, does the page answer?"
  run "systemctl is-active nginx"
  good "active"
  bad  "inactive / failed = the website is down. Next: sudo nginx -t, then sudo systemctl restart nginx"
  run "nginx -t"
  good "'syntax is ok' and 'test is successful'."
  bad  "An error with a file name and line number = fix that line, then run nginx -t again."
  run "ls -l /etc/nginx/sites-enabled/"
  good "The site files you expect (e.g. default, shop)."
  run "curl -s -o /dev/null -w 'http://localhost answers: %{http_code}\n' http://localhost"
  good "200 = the page works. (301/302 = a redirect, also OK.)"
  bad  "502 / 504 = nginx runs but the app or DB behind it does not answer. 000 = nginx does not answer at all."
  run "tail -n 10 /var/log/nginx/error.log"
  good "Empty or old lines."
  bad  "'connect() failed' / 'upstream timed out' = the program behind nginx is down or slow."
fi

if ls /etc/postgresql >/dev/null 2>&1; then
  sec "ROLE: POSTGRESQL (database)"
  about "Does the database run, who may connect, how many connections, how big, any errors?"
  run "pg_lsclusters"
  good "14 main 5432 online"
  bad  "down = the database is stopped. Next: sudo systemctl start postgresql@14-main, then read its log."
  run "grep -E '^(listen_addresses|port|log_min_duration_statement)' /etc/postgresql/*/main/postgresql.conf"
  good "listen_addresses = '*' (needed so app01 can connect) · port 5432 · log_min_duration_statement = 2000 (slow queries logged)."
  bad  "listen_addresses missing or 'localhost' = app01 cannot connect ('Connection refused')."
  run "grep -v '^#' /etc/postgresql/*/main/pg_hba.conf | grep -v '^\$'"
  good "A line: host shop shopapp 192.168.60.10/32 scram-sha-256 = only app01 may use the shop DB."
  bad  "0.0.0.0/0 or 'trust' = anyone (or no password) can connect. Too open."
  run "cd /tmp && sudo -u postgres psql -At -c \"SELECT 'connections now: '||count(*) FROM pg_stat_activity;\""
  good "A small number (under 20 in the lab). The limit is max_connections (100 by default)."
  bad  "Near 100 = new connections will fail with 'too many clients'."
  run "cd /tmp && sudo -u postgres psql -c \"SELECT datname AS database, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE NOT datistemplate;\""
  good "shop and postgres are listed, small sizes (kB / MB)."
  bad  "A database missing = it was dropped or never created. A size that grows very fast = check what writes."
  run "tail -n 10 /var/log/postgresql/postgresql-*-main.log"
  good "Normal start/stop lines, or 'duration:' lines from your own slow-query test."
  bad  "FATAL: password authentication failed = wrong password (check ~/.pgpass on app01). 'no pg_hba.conf entry' = that IP is not allowed."
fi

if active nfs-server; then
  sec "ROLE: NFS SERVER"
  about "Which folders does this server share, and with whom?"
  run "exportfs -v"
  good "The shared folder (e.g. /srv/...) with 192.168.60.10 (app01)."
  bad  "Empty = nothing is shared, app01 cannot mount it. Check /etc/exports, then sudo exportfs -ra"
fi

if [ -d /etc/rsyslog.d ]; then
  sec "ROLE: RSYSLOG (logs)"
  about "Does rsyslog run; does this server receive logs (stor01) or send them (app01, db01)? – Step 5.4"
  run "systemctl is-active rsyslog"
  good "active"
  bad  "inactive = no logs are written to /var/log files or sent to stor01."
  run "grep -h -v '^#' /etc/rsyslog.d/*.conf | grep -E 'imtcp|imudp|omfwd|@@|port'"
  good "stor01: imtcp + port 514 (receives). app01/db01: omfwd to 192.168.60.20 port 514 (sends). Empty = before Step 5.4."
  [ -d /var/log/remote ] && run "ls -l /var/log/remote/"
  [ -d /var/log/remote ] && good "One folder per server that sends logs (app01, db01)."
  [ -d /var/log/remote ] && bad  "A server missing = its logs do not arrive. Check its omfwd line and the firewall on port 514."
fi

if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ]; then
  sec "ROLE: GATEWAY"
  about "Does this server pass traffic from the lab to the internet (gw01)?"
  run "sysctl net.ipv4.ip_forward"
  good "net.ipv4.ip_forward = 1"
  bad  "0 = the lab servers cannot reach the internet through gw01."
  has nft && run "nft list ruleset 2>/dev/null | grep -i -E 'masquerade|snat|dnat' | head"
  has iptables && run "iptables -t nat -S 2>/dev/null | head"
  good "A MASQUERADE line = the lab IPs are hidden behind gw01's outside IP (NAT)."
  bad  "No MASQUERADE line = traffic goes out but answers cannot come back."
fi

echo
echo "End of report – $OUT"
} > "$OUT"

chmod 600 "$OUT"

# a copy in the home folder of the user who ran sudo, so it is easy to find and copy (scp)
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
  HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  mkdir -p "$HOME_DIR/server-reports"
  cp "$OUT" "$HOME_DIR/server-reports/"
  chown -R "$SUDO_USER": "$HOME_DIR/server-reports"
  COPY="$HOME_DIR/server-reports/$(basename "$OUT")"
fi

echo "Report saved: $OUT"
[ -n "$COPY" ] && echo "Copy for you:  $COPY   (read it: less $COPY)"
echo
sed -n '/==== SUMMARY ====/,/^Load:/p' "$OUT"
