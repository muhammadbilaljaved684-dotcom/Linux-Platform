#!/bin/bash
# enable-central-logs.sh – the standard logging setup for one server (Step 5.4b, ticket #12)
# Run once on any server, with sudo:   sudo bash enable-central-logs.sh
# It checks which programs are installed and puts ONE small drop-in file per program in place,
# so their logs reach the central log server (stor01). Existing files are never overwritten.
# Project 2 – Acme Analytics Linux platform
#
#   always              -> /etc/rsyslog.d/90-forward.conf              send every line to stor01 (with a queue)
#   nginx installed     -> /etc/nginx/conf.d/central-logs.conf         access + error log also to syslog
#   PostgreSQL there    -> /etc/postgresql/<ver>/main/conf.d/central-logs.conf   log_destination = 'stderr,syslog'
#   Docker installed    -> /etc/docker/daemon.json                     "log-driver": "journald" (only if the file does not exist)

LOGSERVER="192.168.60.20"     # stor01
PORT="514"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo:  sudo bash $0"; exit 1
fi

has() { command -v "$1" >/dev/null 2>&1; }
say() { printf '%-10s %s\n' "$1" "$2"; }

# put a file in place only if it does not exist yet; return 0 = new file written, 1 = already there
place() {   # place <path> <content>
  if [ -e "$1" ]; then
    say "SKIP" "$1 already exists – left as it is"
    return 1
  fi
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  chmod 644 "$1"
  say "NEW" "$1"
  return 0
}

echo "== enable-central-logs on $(hostname) – log server $LOGSERVER:$PORT =="

# ---------- 1. rsyslog: send everything to stor01 ----------
if [ -f /etc/rsyslog.d/10-receive.conf ]; then
  say "SKIP" "this server is the log server (10-receive.conf found) – it does not send"
else
  if place /etc/rsyslog.d/90-forward.conf \
"*.* action(type=\"omfwd\" target=\"$LOGSERVER\" port=\"$PORT\" protocol=\"tcp\"
    queue.type=\"LinkedList\" queue.filename=\"fwd_stor01\"
    queue.saveOnShutdown=\"on\" action.resumeRetryCount=\"-1\")"; then
    if rsyslogd -N1 >/dev/null 2>&1; then
      systemctl restart rsyslog && say "OK" "rsyslog restarted – every line now goes to $LOGSERVER"
    else
      say "ERROR" "rsyslogd -N1 failed – removing the new file"; rm -f /etc/rsyslog.d/90-forward.conf
    fi
  fi
fi

# ---------- 2. nginx: access + error log also to syslog ----------
if has nginx; then
  if place /etc/nginx/conf.d/central-logs.conf \
"# send nginx logs also to syslog -> rsyslog -> stor01 (own files in /var/log/nginx stay)
access_log syslog:server=unix:/dev/log,tag=nginx_access;
error_log  syslog:server=unix:/dev/log,tag=nginx_error;"; then
    if nginx -t >/dev/null 2>&1; then
      systemctl reload nginx && say "OK" "nginx reloaded – access and error log go to syslog"
    else
      say "ERROR" "nginx -t failed – removing the new file"; rm -f /etc/nginx/conf.d/central-logs.conf
    fi
  fi
else
  say "--" "nginx not installed"
fi

# ---------- 3. PostgreSQL: log also to syslog ----------
if ls /etc/postgresql/*/main/postgresql.conf >/dev/null 2>&1; then
  for conf in /etc/postgresql/*/main/postgresql.conf; do
    dir=$(dirname "$conf")
    ver=$(basename "$(dirname "$dir")")
    if place "$dir/conf.d/central-logs.conf" "log_destination = 'stderr,syslog'"; then
      chown postgres:postgres "$dir/conf.d/central-logs.conf"
      systemctl reload "postgresql@${ver}-main" && say "OK" "PostgreSQL $ver reloaded – its log also goes to syslog"
    fi
  done
else
  say "--" "PostgreSQL not installed"
fi

# ---------- 4. Docker: container logs to journald ----------
if has docker; then
  if place /etc/docker/daemon.json '{ "log-driver": "journald" }'; then
    systemctl restart docker && say "OK" "Docker restarted – NEW containers log to journald"
  fi
else
  say "--" "Docker not installed"
fi

echo "== done. Test:  logger -t central-test \"hello from $(hostname)\"  and look on stor01 in /var/log/remote/$(hostname)/ =="
