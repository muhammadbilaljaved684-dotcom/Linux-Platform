# Acme Analytics: a hardened, observable and recoverable Linux platform

> **Status: in progress.** Built step by step in VMware. Each working day is documented in [`docs/progress/`](docs/progress/) with real screenshots of every result. Every step is explained twice: technically, and in plain words for non-specialists. Unfamiliar terms: see the [glossary](docs/glossary.md).

![Project 2 architecture](docs/project2-architecture.png)

## The problem

Acme Analytics runs a small web app on one server. Disks fill up without warning, backups depend on someone remembering, logs grow forever, admins SSH in from anywhere, nobody notices an outage until a customer emails, and nobody could rebuild the server the same way. The first enterprise customer's security questionnaire asks questions the team cannot answer.

My job as junior platform engineer: build a platform that is **recoverable, observable and least-privilege**, run it like a service desk, and document it.

## What I am building

| VM | Role (plain words) | Role (technical) | IP |
|---|---|---|---|
| gw01 | The gatekeeper – the only door to the internet | Gateway: NAT, iptables firewall, WireGuard VPN, Ansible control node | 192.168.60.1 |
| app01 | The shop window – runs the website | App server: nginx in Docker, monitoring stack (Prometheus, Alertmanager, Grafana) | 192.168.60.10 |
| stor01 | The archive room – files, backups, logs | Storage: LVM, NFS, backups, central log server | 192.168.60.20 |
| svc01 | The help desk – tickets and inventory | Service desk: GLPI tickets, knowledge base, asset inventory | 192.168.60.40 |

## Start here

📖 **[The Day 1 story](docs/progress/day-01-story.md)** – the whole day told step by step: what I did, why, the real screenshot, and why it leads to the next step. Written so that non-specialists can follow it. Also as a document: [Project-2-Day-1-story.odt](docs/progress/Project-2-Day-1-story.odt).

## Where I am now

**Phase 1, Step 1.4** – the servers have fixed addresses, the lab reaches the internet only through gw01, and servers can find each other by name.

| Phase | Topic | Status | Report |
|---|---|---|---|
| 0 | Know the system: kernel, boot, targets | 🟡 gw01 done | [Day 1, part 1](docs/progress/day-01-2026-10-13.md) |
| 1 | Network foundation: static IPs, routing, NAT, names | 🟡 Steps 1.1–1.3 ✅, 1.4 in progress | [Day 1, part 2](docs/progress/day-01-2026-10-13-part2-network.md) |
| 1A | Service desk: GLPI tickets and inventory | ⏳ | |
| 2 | Storage: LVM, NFS, backups, snapshots | ⏳ (data disks ready) | |
| 3 | Automation: systemd services and timers | ⏳ | |
| 4 | Processes, signals, cgroups | ⏳ | |
| 5 | Logging: journald, rsyslog, logrotate | ⏳ | |
| 5A | Monitoring and alerting | ⏳ | |
| 6 | Security hardening | ⏳ | |
| 6A | WireGuard VPN | ⏳ | |
| 7 | Publish the web service (DNAT) | ⏳ | |
| 7A | Ansible: rebuild and joiner/leaver | ⏳ | |
| 8 | Acceptance tests and disaster drill | ⏳ | |

### Achieved so far

- Baseline of kernel, drivers, memory and boot recorded; gw01 switched to server mode (`multi-user.target`).
- Static addressing on all three servers with netplan, verified after reboot.
- app01 and stor01 have **no direct internet connection**; all traffic goes through gw01 (IP forwarding + NAT + stateful firewall rule).
- Name resolution order (`/etc/hosts` before DNS) demonstrated.
- 10 issues found and documented with cause and fix (wrong file name, keyboard-layout paste corruption, adapter still connected, missing disks, …).

## Repository layout

```text
linux-platform/
  README.md                     this page
  docs/
    project2-architecture.png   architecture diagram
    glossary.md                 plain-language explanation of every term
    progress/                   one technical report per working day
    images/day-01/              screenshots of every result
```

## Results

*Filled in with measured numbers after Phase 8: time to detect each alert, rebuild time, RTO/RPO, tickets handled.*
