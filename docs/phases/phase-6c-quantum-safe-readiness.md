# Phase 6C: Quantum-safe readiness (post-quantum cryptography)

> **Status: planned.** Runs after Phase 6 (security hardening) and 6A (WireGuard), and before Phase 7, so the web service is published with quantum-safe encryption from day one.

## The problem (plain words)

Today's encryption is like a lock that normal computers would need thousands of years to open. Future quantum computers could open it quickly. Attackers can already **copy encrypted traffic now and unlock it later** ("harvest now, decrypt later").

The EU's coordinated post-quantum roadmap (June 2025) asks organisations to **start the move to quantum-safe encryption by the end of 2026** and to protect high-risk systems **by 2030**. The first step for everyone is a **crypto inventory**: knowing which systems use which encryption.

Acme's security questionnaire now asks: *"Which of your systems use quantum-vulnerable encryption, and what is your migration plan?"* This phase answers that question for the Acme platform.

## Why it fits this platform

| VM | What uses encryption | What this phase does |
|---|---|---|
| gw01 | SSH (admin access), WireGuard VPN | Switch SSH to a hybrid quantum-safe key exchange; add a WireGuard pre-shared key |
| app01 | nginx (HTTPS, in Docker) | Serve HTTPS with hybrid quantum-safe TLS |
| stor01 | SSH, NFS, backup transfers over SSH | Inventory; backups over SSH inherit the safer key exchange |
| svc01 | GLPI web interface | Inventory; record in GLPI as a Change |

The servers run Ubuntu 22.04 (OpenSSL 3.0, OpenSSH 8.9). OpenSSL 3.0 has no post-quantum algorithms, so quantum-safe TLS runs **inside a Docker container** with OpenSSL 3.5+. This is also how real companies pilot new crypto without touching the host.

## Steps

| Step | What I do | Tools |
|---|---|---|
| 6C.1 | List every listening service on all four servers | `ss -tulpn`, `nmap -sV` from gw01 |
| 6C.2 | Scan TLS settings and certificates of every HTTPS service (app01 nginx, svc01 GLPI) | `testssl.sh`, `nmap --script ssl-enum-ciphers` |
| 6C.3 | Check which SSH key-exchange methods each server offers | `ssh -Q kex`, `nmap --script ssh2-enum-algos` |
| 6C.4 | Build the **crypto inventory** (service, algorithm, key size, certificate expiry, quantum-safe yes/no) | `docs/crypto-inventory.md` |
| 6C.5 | **SSH:** enable the hybrid key exchange `sntrup761x25519-sha512@openssh.com` (already in OpenSSH 8.9, but not the default) and prove it is negotiated | `sshd_config` `KexAlgorithms`, `ssh -vv` |
| 6C.6 | **HTTPS:** run nginx on app01 from an image with OpenSSL 3.5+ and enable the hybrid group `X25519MLKEM768` | `ssl_ecdh_curve X25519MLKEM768:X25519;` |
| 6C.7 | Prove it: connect with a post-quantum-capable client and capture the negotiated group | `openssl s_client -groups X25519MLKEM768` (OpenSSL 3.5 container), Wireshark |
| 6C.8 | **VPN:** add a WireGuard `PresharedKey` between gw01 and the admin laptop (WireGuard's documented extra layer against future quantum attacks) | `wg genpsk` |
| 6C.9 | Raise a **Change ticket in GLPI**, then write the one-page **migration plan**: what was changed, what stays classical for now and why, next steps when Ubuntu 24.04/26.04 is rolled out | GLPI, `docs/pqc-migration-plan.md` |

## Evidence planned

- Crypto inventory table: before and after
- `testssl.sh` / `s_client` screenshot showing `X25519MLKEM768`
- `ssh -vv` screenshot showing `kex: algorithm: sntrup761x25519-sha512@openssh.com`
- GLPI Change ticket
- One-page migration plan

## Key terms (plain words)

- **Post-quantum cryptography (PQC):** new encryption methods that quantum computers cannot break.
- **ML-KEM:** the new standard for two computers to agree on a secret key safely (NIST FIPS 203). It replaces RSA/ECDH key exchange.
- **ML-DSA:** the new standard for digital signatures and certificates (NIST FIPS 204).
- **Hybrid:** old and new methods used together, so the connection stays safe even if one of them fails.
- **Crypto inventory:** the list of where encryption is used. It is the first step of every migration.
- **Crypto-agility:** building systems so encryption can be swapped without rebuilding everything.
