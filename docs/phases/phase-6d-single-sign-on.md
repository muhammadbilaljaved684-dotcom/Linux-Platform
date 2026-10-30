# Phase 6D: Single sign-on with Keycloak (identity and access management)

> **Status: planned.** Runs after Phase 6C. Uses the hardened servers, the VPN and the certificates from 6C.

## The problem (plain words)

Acme's admins have a separate password for every tool: Grafana, GLPI, the servers. When someone leaves the company, nobody is sure every account was closed. The customer's security questionnaire asks: *"Do you use central login (SSO), and how do you remove access when an employee leaves?"*

**Single sign-on (SSO)** means one central login service. You log in once and every tool trusts it. Disable the person in one place and all access is gone. Companies use Microsoft Entra ID, Okta, Airlock IAM or **Keycloak**, the free open-source one used by many German companies and public bodies.

## What I build

| Part | Where | What it does |
|---|---|---|
| Keycloak (Docker) | svc01 | Central login service with realm `acme`, users and groups (`admins`, `support`) |
| Grafana login via OIDC | app01 | Grafana sends users to Keycloak; group `admins` becomes Grafana Admin |
| GLPI login via SAML | svc01 | Second protocol: GLPI trusts Keycloak through a SAML plugin |
| HTTPS with own CA | svc01 | Keycloak only reachable over HTTPS, certificate from the internal CA (links to 6C) |
| Joiner / leaver | Keycloak + Ansible (7A) | Disable a user once → login to Grafana and GLPI fails everywhere |

svc01 has 2 GB RAM. Keycloak and Greenbone need memory, so raise svc01 to 4 GB or don't run a Greenbone scan at the same time.

## Steps

| Step | What I do | Evidence |
|---|---|---|
| 6D.1 | Run Keycloak in Docker on svc01 behind HTTPS | Keycloak admin page over HTTPS |
| 6D.2 | Create realm `acme`, groups `admins` and `support`, two test users, password policy and MFA (TOTP) for admins | Screenshot of realm settings |
| 6D.3 | Connect Grafana with **OIDC** (OpenID Connect); map group → Grafana role | Login redirect to Keycloak, user lands with the right role |
| 6D.4 | Connect GLPI with **SAML** | Login to GLPI through Keycloak |
| 6D.5 | Decode a token (JWT) and a SAML assertion and explain each field | Annotated screenshot |
| 6D.6 | **Leaver test:** disable a user in Keycloak → access to both tools stops; measure the time | Results table |
| 6D.7 | Break and fix: wrong redirect URI, clock skew between servers, expired certificate | Three GLPI incident tickets with cause and fix |

## Key terms (plain words)

- **IAM (Identity and Access Management):** managing who you are (identity) and what you may do (access).
- **SSO (single sign-on):** log in once, use every tool.
- **OIDC (OpenID Connect):** modern login protocol built on OAuth 2.0, used by web apps. It carries identity in a token (JWT).
- **OAuth 2.0:** the standard for giving an app limited access without sharing your password.
- **SAML:** older XML-based login protocol, still very common in enterprises.
- **MFA:** a second factor besides the password, e.g. a code from an app.
- **Joiner / mover / leaver:** the process of giving, changing and removing access when people join, change role or leave.
