# Phase 7B: Running a business application (CRM)

> **Status: planned.** Runs after Phase 7 (the web service is published) and uses Phase 6D (Keycloak) for login.

## The problem (plain words)

Acme's sales team keeps customer contacts in spreadsheets on their laptops. Management wants a central **CRM** (Customer Relationship Management: one place for customers, contacts, deals and support cases). IT does not use the CRM itself. IT **runs** it: installs it, controls who can log in, backs it up, monitors it, updates it and helps users when something breaks.

That is exactly what job ads mean when they list "CRM" or "Fachanwendungen" (business applications) for an IT administrator: operating the application, not selling with it. Companies use Salesforce, HubSpot, Microsoft Dynamics 365 or the open-source **SuiteCRM**. This phase uses SuiteCRM because it is free and self-hosted.

## What I build

| Part | Where | What it shows |
|---|---|---|
| SuiteCRM + MariaDB in Docker | app01 | Installing a business application with its database |
| Published through nginx over HTTPS | app01 / gw01 | Same path as the website from Phase 7 |
| Users, roles, teams (Sales, Support, Admin) | SuiteCRM | Least privilege inside an application |
| Login through Keycloak (SAML) | svc01 | Leaver test now also covers the CRM |
| Nightly database dump + restore test | stor01 | A business app is only safe if its data can come back |
| Uptime check + alert | Prometheus blackbox | IT knows before users call |
| Update with rollback plan | GLPI Change ticket | How companies update business software |

## Steps

| Step | What I do | Evidence |
|---|---|---|
| 7B.1 | Run SuiteCRM and MariaDB with Docker Compose, data on a named volume | CRM login page |
| 7B.2 | Publish it through nginx with HTTPS | Browser over the VPN |
| 7B.3 | Create roles and teams; test that a Sales user cannot see Admin settings | Two screenshots |
| 7B.4 | Connect login to Keycloak; disable a user → CRM access gone too | Leaver results table |
| 7B.5 | Nightly `mysqldump` to stor01 by systemd timer; restore into a test container; measure the time | Restore time (RTO) |
| 7B.6 | Add the CRM URL to blackbox monitoring; stop the container → alert fires | Alert screenshot |
| 7B.7 | User tickets in GLPI: "I can't log in to the CRM", "export to Excel fails"; solve and write KB articles | Two tickets + KB |
| 7B.8 | Update SuiteCRM through a GLPI Change: snapshot, update, test, rollback plan | Change ticket |

## Key terms (plain words)

- **CRM:** software for managing customers, contacts, sales and support cases.
- **Business application (Fachanwendung):** software a department uses for its daily work, run by IT.
- **Application administration:** installing, configuring, securing, backing up, updating and supporting such software.
- **RTO:** how long it takes to get the service back after a failure.
