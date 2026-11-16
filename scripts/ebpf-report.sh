#!/bin/bash
# ebpf-report.sh – "what is this server actually doing?" in one run (Step 5.7, ticket #16)
# Project 2 – Acme Analytics Linux platform
#
# Run:   sudo bash ebpf-report.sh            (watches for 30 seconds)
#        sudo bash ebpf-report.sh 60         (watches for 60 seconds)
# While it watches, use the server normally (or make the problem happen) – then read the report.
#
# Level 1 (how much)   = Grafana / Prometheus, or server-report.sh
# Level 2 (which one)  = top, ps, iotop, ss
# Level 3 (what exactly, from the kernel) = THIS script – the checks SREs run first with eBPF:
#
#   1 New programs        who started which program            (like execsnoop)
#   2 Files opened        which files, and which failed         (like opensnoop)
#   3 On the CPU          which programs actually use the CPU   (like profile)
#   4 Waiting for CPU     how long programs wait for a CPU      (like runqlat)
#   5 Disk                who writes/reads, how fast the disk   (like biotop + biolatency)
#   6 TCP connections     who connects where, how long, which failed (like tcplife / tcpconnect)
#   7 TCP retransmits     lost packets, per address             (like tcpretrans)
#   8 OOM kills           processes killed because RAM ran out  (like oomkill)
#   9 Kill signals        who sent kill / stop to whom          (like killsnoop)
#
# Uses bpftrace with stable kernel tracepoints – no kernel headers needed, so it also works
# where the older BCC tools fail to compile. Each check is added only if this kernel has it.
# The report is also saved to ~/ebpf-reports/ of the user who ran sudo.

DUR="${1:-30}"

if [ "$(id -u)" -ne 0 ]; then echo "Please run with sudo:  sudo bash $0 [seconds]"; exit 1; fi
if ! command -v bpftrace >/dev/null 2>&1; then
  echo "bpftrace is missing – install it:  sudo apt install -y bpftrace"; exit 1
fi
case "$DUR" in ''|*[!0-9]*) echo "Seconds must be a number, e.g. 30"; exit 1;; esac

has() { bpftrace -l "$1" 2>/dev/null | grep -q .; }

PROG=$(mktemp /tmp/ebpf-report.XXXXXX.bt)
trap 'rm -f "$PROG"' EXIT
SKIPPED=""
add() { printf '%s\n' "$1" >> "$PROG"; }

# No BEGIN/END blocks: Ubuntu 22.04's bpftrace 0.14 fails on them ("Could not resolve symbol … BEGIN_trigger").
# The report is printed by the timer probe itself, which then ends the run.

# 1 – new programs
if has 'tracepoint:syscalls:sys_enter_execve'; then
add 'tracepoint:syscalls:sys_enter_execve { @exec_total = count(); @exec[comm, str(args->filename)] = count(); }'
else SKIPPED="$SKIPPED 1-new-programs"; fi

# 2 – files opened (ok and failed)
if has 'tracepoint:syscalls:sys_enter_openat'; then
add 'tracepoint:syscalls:sys_enter_openat { @fn[tid] = args->filename; }'
add 'tracepoint:syscalls:sys_exit_openat /@fn[tid]/ {
  if (args->ret < 0) { @open_fail[comm, str(@fn[tid])] = count(); }
  else               { @open_ok[comm, str(@fn[tid])] = count(); }
  delete(@fn[tid]); }'
else SKIPPED="$SKIPPED 2-files"; fi

# 3 – who is on the CPU (sampled 49 times a second)
add 'profile:hz:49 /pid != 0/ { @oncpu[comm] = count(); }'

# 4 – waiting for a CPU (run-queue latency)
if has 'tracepoint:sched:sched_switch'; then
add 'tracepoint:sched:sched_wakeup, tracepoint:sched:sched_wakeup_new { @qt[args->pid] = nsecs; }'
add 'tracepoint:sched:sched_switch {
  if (args->prev_state == 0) { @qt[args->prev_pid] = nsecs; }
  $t = @qt[args->next_pid];
  if ($t) { @runq_us = hist((nsecs - $t) / 1000); }
  delete(@qt[args->next_pid]); }'
else SKIPPED="$SKIPPED 4-cpu-wait"; fi

# 5 – disk: who sends I/O, and how long the disk takes
if has 'tracepoint:block:block_rq_issue'; then
add 'tracepoint:block:block_rq_issue { @bio[args->dev, args->sector] = nsecs; @disk_kb[comm] = sum(args->bytes / 1024); }'
add 'tracepoint:block:block_rq_complete /@bio[args->dev, args->sector]/ {
  @disk_us = hist((nsecs - @bio[args->dev, args->sector]) / 1000);
  delete(@bio[args->dev, args->sector]); }'
else SKIPPED="$SKIPPED 5-disk"; fi

# 6 – TCP connections: out (we connect), in (they connect), duration, failed
# Split into small probes: one big probe was rejected by the kernel's verifier on app01.
if has 'tracepoint:sock:inet_sock_set_state'; then
add 'tracepoint:sock:inet_sock_set_state /args->protocol == 6 && args->newstate == 2/ {
  @tcp_out[comm, ntop(args->daddr), args->dport] = count(); }'
add 'tracepoint:sock:inet_sock_set_state /args->protocol == 6 && args->oldstate == 3 && args->newstate == 1/ {
  @tcp_in[ntop(args->daddr), args->sport] = count(); }'
add 'tracepoint:sock:inet_sock_set_state /args->protocol == 6 && args->newstate == 1/ {
  @st[args->skaddr] = nsecs; }'
add 'tracepoint:sock:inet_sock_set_state /args->protocol == 6 && args->newstate == 7 && @st[args->skaddr]/ {
  $ms = (nsecs - @st[args->skaddr]) / 1000000;
  @tcp_ms = hist($ms);
  @tcp_long[ntop(args->daddr), args->dport, args->sport] = max($ms);
  delete(@st[args->skaddr]); }'
add 'tracepoint:sock:inet_sock_set_state /args->protocol == 6 && args->oldstate == 2 && args->newstate == 7/ {
  @tcp_fail[ntop(args->daddr), args->dport] = count(); }'
else SKIPPED="$SKIPPED 6-tcp"; fi

# 7 – TCP retransmits
if has 'tracepoint:tcp:tcp_retransmit_skb'; then
add 'tracepoint:tcp:tcp_retransmit_skb { @retrans[ntop(args->daddr), args->dport] = count(); }'
else SKIPPED="$SKIPPED 7-retransmits"; fi

# 8 – OOM kills
if has 'tracepoint:oom:mark_victim'; then
add 'tracepoint:oom:mark_victim { @oom[args->pid] = count(); printf("!! OOM kill: pid %d\n", args->pid); }'
else SKIPPED="$SKIPPED 8-oom"; fi

# 9 – kill / stop signals
if has 'tracepoint:signal:signal_generate'; then
add 'tracepoint:signal:signal_generate /args->sig == 9 || args->sig == 15/ { @sig[comm, args->comm, args->sig] = count(); }'
else SKIPPED="$SKIPPED 9-signals"; fi

# the report – helper maps are cleared so only the sections below are printed
add "interval:s:$DUR {"
add '
  clear(@fn); clear(@qt); clear(@bio); clear(@st);
  printf("\n==================== eBPF REPORT ====================\n");
  printf("Empty section = nothing of that kind happened while watching.\n");

  printf("\n== 1. NEW PROGRAMS – who started what (parent, program: how often) ==\n");
  printf("   look for: something started hundreds of times, or a program you do not know\n");
  print(@exec_total); print(@exec, 15); clear(@exec_total); clear(@exec);

  printf("\n== 2a. FILES OPENED – top 15 (program, file: how often) ==\n");
  printf("   look for: one program opening the same file again and again\n");
  print(@open_ok, 15); clear(@open_ok);
  printf("\n== 2b. FILES THAT FAILED TO OPEN (missing, no permission) ==\n");
  printf("   look for: a config file or log that keeps failing = a broken setting\n");
  print(@open_fail, 15); clear(@open_fail);

  printf("\n== 3. ON THE CPU – samples per program (49 per second = one full CPU) ==\n");
  printf("   look for: one program far above the rest\n");
  print(@oncpu, 10); clear(@oncpu);

  printf("\n== 4. WAITING FOR A CPU – microseconds (run-queue latency) ==\n");
  printf("   good: most under 100 us · bad: many in the ms range = not enough CPUs\n");
  print(@runq_us); clear(@runq_us);

  printf("\n== 5a. DISK – KB sent to the disk per program ==\n");
  print(@disk_kb, 10); clear(@disk_kb);
  printf("\n== 5b. DISK – how long each disk request took, microseconds ==\n");
  printf("   good (SSD/VM): mostly under 1 000 us · bad: many above 10 000 us = slow disk\n");
  print(@disk_us); clear(@disk_us);

  printf("\n== 6a. TCP OUT – this server tried to connect to (program, address, port: count) ==\n");
  print(@tcp_out, 15); clear(@tcp_out);
  printf("\n== 6b. TCP IN – connected to this server (from address, our port: count) ==\n");
  printf("   look for: one address with very many connections = a scanner or a stuck client\n");
  print(@tcp_in, 15); clear(@tcp_in);
  printf("\n== 6c. TCP – how long connections lasted, ms ==\n");
  print(@tcp_ms); clear(@tcp_ms);
  printf("\n== 6d. TCP – longest connections (address, remote port, local port: ms) ==\n");
  printf("   look for: a database or API call that takes seconds\n");
  print(@tcp_long, 10); clear(@tcp_long);
  printf("\n== 6e. TCP – FAILED connections, never opened (address, port: count) ==\n");
  printf("   good: empty · bad: a program that keeps trying a server that is down or blocked\n");
  print(@tcp_fail, 10); clear(@tcp_fail);

  printf("\n== 7. TCP RETRANSMITS – packets sent again (address, port: count) ==\n");
  printf("   good: empty · bad: many = network problem to that address\n");
  print(@retrans, 10); clear(@retrans);

  printf("\n== 8. OOM KILLS – processes killed because RAM ran out (pid) ==\n");
  printf("   good: empty\n");
  print(@oom); clear(@oom);

  printf("\n== 9. KILL SIGNALS – sender, target, signal (9 = kill, 15 = stop) ==\n");
  print(@sig, 10); clear(@sig);
  printf("\n=====================================================\n");
  exit();
}'

OUTDIR="/root/ebpf-reports"
if [ -n "$SUDO_USER" ]; then OUTDIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)/ebpf-reports"; fi
mkdir -p "$OUTDIR"
OUT="$OUTDIR/ebpf-$(hostname)-$(date +%Y-%m-%d-%H%M).txt"

{
  echo "eBPF report – $(hostname) – $(date '+%Y-%m-%d %H:%M:%S %Z') – kernel $(uname -r) – $DUR s"
  [ -n "$SKIPPED" ] && echo "SKIPPED (this kernel has no tracepoint for):$SKIPPED"
} | tee "$OUT"

echo "Watching $(hostname) for $DUR seconds … use the server now. (Ctrl+C = stop early – then no report)"
# after the report, bpftrace still dumps its (now empty) maps while it exits – hide everything after the last ===== line
BPFTRACE_STRLEN=96 bpftrace "$PROG" 2>&1 | grep -v -E '^Attaching [0-9]+ probes' \
  | awk '!done {print} /^=+$/ && length($0) == 53 {done = 1}' | tee -a "$OUT"

[ -n "$SUDO_USER" ] && chown -R "$SUDO_USER": "$OUTDIR"
echo "Saved: $OUT"
