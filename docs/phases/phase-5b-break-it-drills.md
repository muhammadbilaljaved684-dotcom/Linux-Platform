# Phase 5B – "Break it" drills (planned, after Phase 5A)

**Ticket #17 · Problem · "Break it" drills:** Production fails in chains. Break the lab on purpose (full disk, NFS down mid-backup, too many open files, packet loss), find the first cause each time, write a short postmortem. After Phase 5A, so the alerts are tested too.

Idea from a LinkedIn comment by a Linux systems engineer: *"Production rarely breaks one thing at a time. It tends to break three things and blame a fourth."*

▶ Video of the idea on this lab: [breaking-things-on-purpose.mp4](../videos/breaking-things-on-purpose.mp4)

## The four drills

| # | Break this | What else fails (the chain) | What gets blamed first | Find the first cause with | Revises |
|---|---|---|---|---|---|
| 1 | fill db01's disk while PostgreSQL writes | shop errors · db01's logs stop on stor01 | app01 / the network | `df -h`, `du`, `journalctl -u postgresql@14-main`, `ebpf-report.sh` | Phase 2, Phase 5 |
| 2 | stop NFS on stor01 during a backup | app01 hangs on `/mnt/app` · backup "done" but empty | app01 overloaded | `ps` (state D), `strace -p`, `ss`, `journalctl -k` | Phase 2, Phase 3 |
| 3 | exhaust nginx file descriptors | new visitors get errors, CPU/RAM look fine | "nothing is wrong" | `ulimit -n`, `/proc/<pid>/fd`, nginx `error.log` | Phase 4 |
| 4 | packet loss app01 ↔ db01 (`tc netem`) | shop slow, many retries | the database | `tcplife.bt`, `ebpf-report.sh` (retransmits), `ss -ti`, `tcpdump` | Phase 1, Step 5.7 |

## For every drill

1. GLPI ticket – what users see.
2. Did monitoring (Phase 5A) alert, and how fast?
3. Dig down: how much → which process → what exactly.
4. Fix, then a short postmortem: first cause · chain · what got blamed · how to prevent it.

Status: **planned** – nothing run yet.
