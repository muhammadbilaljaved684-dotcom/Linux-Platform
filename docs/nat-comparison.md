# Step 1.9 – Linux NAT vs Cloud NAT

💡 **In plain words:** NAT is the mailroom that swaps the private sender address for the company's public address on the way out and hands the replies back to the right person. In my lab I **build** that mailroom myself on gw01. In the cloud you **rent** it as a ready-made service.

![Where does NAT live? Linux NAT in my lab vs AWS NAT Gateway](images/nat-linux-vs-cloud.png)

## Where the NAT sits

| | My lab (gw01) | Cloud (AWS) |
|---|---|---|
| **The NAT itself** | 3 kernel settings on one VM: `ip_forward = 1`, iptables `MASQUERADE`, `FORWARD` rules | A **NAT Gateway** placed in a **public subnet** |
| **How servers find it** | `default via 192.168.60.1` in netplan on each server | Private subnet route table `0.0.0.0/0 → nat-xxxx` |
| **Public address** | The address of gw01's outside card (VMware NAT / home router) | An **Elastic IP** attached to the NAT Gateway |
| **Way out to the internet** | Home router / VMnet8 | **Internet Gateway** (public subnet route `0.0.0.0/0 → igw`) |
| **Firewall** | iptables `FORWARD` chain | Security Groups + Network ACLs |

## Comparison across providers

| | gw01 (mine) | AWS NAT Gateway | Azure NAT Gateway | GCP Cloud NAT |
|---|---|---|---|---|
| **Who runs it** | Me | AWS (managed) | Azure (managed) | Google (managed) |
| **Where** | One VM | Public subnet; private route table `0.0.0.0/0 → nat-xxxx` | Attached to a subnet | Configured on a Cloud Router; no NAT VM at all (software-defined) |
| **High availability** | None – one VM is a single point of failure | Redundant inside one Availability Zone; one gateway per AZ for full resilience | Managed, zonal | Managed, distributed |
| **Public IP** | Address of the NAT adapter | Elastic IP | Public IP(s) or prefix | Auto-allocated or reserved IPs |
| **Cost model** | The VM I already run | Per hour + per GB processed | Per hour + per GB processed | Per hour + per GB processed |

## In three sentences

1. **What stays the same:** the job – outbound source translation, so private servers reach the internet while nobody on the internet can open a connection to them.
2. **What the cloud adds:** the provider runs, patches, scales and keeps the NAT available; in my lab, if gw01 is off, app01 and stor01 lose the internet.
3. **What I would watch:** cost – managed NAT is charged per hour **and per GB**, so heavy traffic (updates, backups, container image pulls) through it gets expensive; options such as VPC endpoints for cloud storage keep that traffic off the NAT.

## Key understanding (in my own words)

> In my lab the NAT is not a box – it is three settings inside gw01: forwarding on, a MASQUERADE rule, and FORWARD rules that let replies back. Servers reach it because their default route points to gw01. In the cloud the same job is a managed NAT Gateway in a public subnet, reached through a route table entry and given a fixed Elastic IP; the provider keeps it running and bills per hour and per GB. Same job, different owner.

← Back to the [Day 2 report](progress/day-02-2026-10-15.md) · [README](../README.md)
