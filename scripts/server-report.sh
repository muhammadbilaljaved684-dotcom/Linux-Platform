#!/bin/bash
# server-report.sh – a full "check-up" of one Linux server, saved in one file.
# Read-only: it only looks, it changes nothing. Run it with sudo on any server:
#   sudo bash server-report.sh
# Output: /var/tmp/server-report-<host>-<date>.txt  (a summary with WARN lines on top)
# Project 2 – Acme Analytics Linux platform

HOST=$(hostname)
STAMP=$(date +%Y-%m-%d_%H%M)
OUT="/var/tmp/server-report-${HOST}-${STAMP}.txt"
WARN=()

has() { command -v "$1" >/dev/null 2>&1; }
active() { systemctl is-active --quiet "$1" 2>/dev/null; }
sec() { printf '\n==================== %s ====================\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }
warn() { WARN+=("$1"); }

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo:  sudo bash $0"; exit 1
fi

KERNEL_WORDS="out of memory|oom|killed process|soft lockup|stuck|hung_task|blocked for more than|i/o error|ext4-fs error|read-only|link is down|reset adapter|timed out|segfault|call trace|conntrack.*full|throttl"

# ---------- quick checks for the summary ----------
CPUS=$(nproc)
LOAD=$(cut -d' ' -f1 /proc/loadavg)
awk -v l="$LOAD" -v c="$CPUS" 'BEGIN{exit !(l>c)}' && warn "Load $LOAD is higher than the $CPUS CPUs – the CPU is busy"

MEM_AVAIL_PCT=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d", a*100/t}' /proc/meminfo)
[ "$MEM_AVAIL_PCT" -lt 10 ] && warn "Only ${MEM_AVAIL_PCT}% RAM available"
SWAP_USED=$(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print t-f}' /proc/meminfo)
[ "$SWAP_USED" -gt 102400 ] && warn "Swap in use: $((SWAP_USED/1024)) MB – RAM was short at some point"

while read -r use mnt; do
  p=${use%\%}; [ "$p" -ge 85 ] 2>/dev/null && warn "Disk $mnt is ${use} full"
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1{print $5, $6}')
while read -r use mnt; do
  p=${use%\%}; [ "$p" -ge 85 ] 2>/dev/null && warn "Inodes on $mnt are ${use} used"
done < <(df -P -i -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 && $5!="-"{print $5, $6}')

FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | xargs)
[ -n "$FAILED" ] && warn "Failed services: $FAILED"

KPROB=$(journalctl -k -b -p warning --no-pager 2>/dev/null | grep -i -c -E "$KERNEL_WORDS")
[ "$KPROB" -gt 0 ] && warn "Kernel log (this run): $KPROB problem line(s) – see section KERNEL"
ERR24=$(journalctl -p err --since "24 hours ago" --no-pager -q 2>/dev/null | wc -l)
[ "$ERR24" -gt 0 ] && warn "$ERR24 error line(s) in the journal in the last 24 hours"

if has lsof; then
  DELOPEN=$(lsof -nP +L1 2>/dev/null | awk 'NR>1' | wc -l)
  [ "$DELOPEN" -gt 0 ] && warn "$DELOPEN deleted file(s) still open (space not freed) – lsof +L1"
fi
[ -f /var/run/reboot-required ] && warn "A reboot is required (updates)"
if has timedatectl; then
  timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes || warn "Clock is not synchronised (NTP)"
fi
if has apt; then
  UPG=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
  [ "$UPG" -gt 0 ] && warn "$UPG package update(s) waiting"
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

sec "SUMMARY"
if [ ${#WARN[@]} -eq 0 ]; then
  echo "OK – no warnings found."
else
  for w in "${WARN[@]}"; do echo "WARN  $w"; done
fi
echo "Load: $LOAD on $CPUS CPUs · RAM available: ${MEM_AVAIL_PCT}% · kernel problem lines: $KPROB · errors 24h: $ERR24"

sec "SYSTEM"
run "hostnamectl 2>/dev/null | grep -E 'Static hostname|Operating System|Kernel|Virtualization'"
run "uptime"
run "last -x reboot shutdown 2>/dev/null | head -5"
run "journalctl --list-boots --no-pager | tail -3"
run "timedatectl 2>/dev/null | grep -E 'Local time|synchronized|Time zone'"

sec "CPU AND MEMORY"
run "lscpu | grep -E 'Model name|^CPU\(s\)'"
run "free -h"
run "vmstat 1 3"
run "ps -eo pid,user,%cpu,%mem,stat,cmd --sort=-%cpu | head -6"
run "ps -eo pid,user,%cpu,%mem,stat,cmd --sort=-%mem | head -6"
run "ps -eo pid,stat,cmd | awk '\$2 ~ /^D/'"

sec "DISKS"
run "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT"
run "df -h -x tmpfs -x devtmpfs -x squashfs"
run "df -i -x tmpfs -x devtmpfs -x squashfs"
run "findmnt -t nfs,nfs4 2>/dev/null"
has iostat && run "iostat -xz 1 2 | tail -n +4"

sec "NETWORK"
run "ip -br a"
run "ip route"
run "resolvectl dns 2>/dev/null || cat /etc/resolv.conf"
run "grep -v '^#' /etc/hosts | grep -v '^\$'"
run "ss -tlnp"
run "ss -s | head -3"

sec "SERVICES"
run "systemctl --failed --no-pager"
run "systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print \$1}'"
run "systemctl list-timers --no-pager | head -12"

sec "KERNEL (problem words)"
echo "Words searched: $KERNEL_WORDS"
run "journalctl -k -b -p warning --no-pager | grep -i -E \"$KERNEL_WORDS\" | tail -30"
echo "--- run before (-b -1) ---"
run "journalctl -k -b -1 -p warning --no-pager 2>/dev/null | grep -i -E \"$KERNEL_WORDS\" | tail -15"

sec "ERRORS (last 24 hours)"
run "journalctl -p err --since '24 hours ago' --no-pager -q | tail -30"

sec "USERS AND LOGINS"
run "who"
run "last -n 8 | head -8"
run "getent group sudo"

sec "SECURITY"
has ufw && run "ufw status"
run "sshd -T 2>/dev/null | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '"
has aa-status && run "aa-status 2>/dev/null | head -3"
[ -f /var/log/auth.log ] && run "grep -c 'Failed password' /var/log/auth.log"

sec "UPDATES"
has apt && run "apt list --upgradable 2>/dev/null | head -15"

# ---------- role sections ----------
if active nginx || has nginx; then
  sec "ROLE: NGINX (web server)"
  run "systemctl is-active nginx"
  run "nginx -t"
  run "ls -l /etc/nginx/sites-enabled/"
  run "curl -s -o /dev/null -w 'http://localhost answers: %{http_code}\n' http://localhost"
  run "tail -n 10 /var/log/nginx/error.log"
fi

if ls /etc/postgresql >/dev/null 2>&1; then
  sec "ROLE: POSTGRESQL (database)"
  run "pg_lsclusters"
  run "grep -E '^(listen_addresses|port|log_min_duration_statement)' /etc/postgresql/*/main/postgresql.conf"
  run "grep -v '^#' /etc/postgresql/*/main/pg_hba.conf | grep -v '^\$'"
  run "cd /tmp && sudo -u postgres psql -At -c \"SELECT 'connections now: '||count(*) FROM pg_stat_activity;\""
  run "cd /tmp && sudo -u postgres psql -c \"SELECT datname AS database, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE NOT datistemplate;\""
  run "tail -n 10 /var/log/postgresql/postgresql-*-main.log"
fi

if active nfs-server; then
  sec "ROLE: NFS SERVER"
  run "exportfs -v"
fi

if [ -d /etc/rsyslog.d ]; then
  sec "ROLE: RSYSLOG (logs)"
  run "systemctl is-active rsyslog"
  run "grep -h -v '^#' /etc/rsyslog.d/*.conf | grep -E 'imtcp|imudp|omfwd|@@|port'"
  [ -d /var/log/remote ] && run "ls -l /var/log/remote/"
fi

if [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ]; then
  sec "ROLE: GATEWAY"
  run "sysctl net.ipv4.ip_forward"
  has nft && run "nft list ruleset 2>/dev/null | grep -i -E 'masquerade|snat|dnat' | head"
  has iptables && run "iptables -t nat -S 2>/dev/null | head"
fi

echo
echo "End of report – $OUT"
} > "$OUT"

chmod 600 "$OUT"
echo "Report saved: $OUT"
echo
sed -n '/==== SUMMARY ====/,/^Load:/p' "$OUT"
