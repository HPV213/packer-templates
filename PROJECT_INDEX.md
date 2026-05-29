# Project Index: packer-templates

Generated: 2026-05-30 | Stack: Packer HCL + Proxmox VE | Files: 79 (excl. .git)

## Project Structure

```
packer-templates/
├── config.pkr.hcl                   # Packer plugin declaration (Proxmox v1.2.3)
├── variables.pkr.hcl                # All variable definitions + defaults (378 lines)
├── generic.pkr.hcl                  # Shared build logic — source + build blocks (142 lines)
├── *.pkrvars.hcl                    # 21 OS-specific variable files
├── http/                            # Unattended install configs (served via HTTP)
│   ├── alpine/answers               #   Alpine answer file
│   ├── debian/preseed.cfg           #   Debian preseed (shared by Debian 11-13)
│   ├── ubuntu/user-data             #   Ubuntu cloud-init autoinstall (20.04+)
│   ├── ubuntu-18.04/preseed.cfg     #   Ubuntu 18.04 preseed
│   ├── ubuntu/meta-data             #   Empty cloud-init meta-data
│   ├── rocky-{9,10}/ks.cfg         #   Rocky kickstart
│   ├── almalinux-{9,10}/ks.cfg     #   AlmaLinux kickstart
│   ├── windows/                     #   Windows unattended XML templates
│   │   ├── Autounattend-server.xml.pkrtpl  # Server 2019/2022/2025
│   │   └── Autounattend-win11.xml.pkrtpl   # Windows 11
│   ├── windows-scripts/setup.ps1    #   WinRM + RDP setup script
│   ├── talos/schematic.yaml         #   Talos extension config
│   └── vyos/qemu-guest-agent.sh     #   VyOS guest agent installer
├── .github/
│   ├── workflows/
│   │   ├── packer.yml               #   Reusable build workflow (workflow_call)
│   │   ├── validate-iso.yml         #   PR: validate ISO URLs + checksums
│   │   └── <os>.yml (x24)          #   Per-OS workflow triggers
│   └── renovate.json5               #   Renovate: custom datasources + version rules
├── terraform-template-test/         #   Template validation (clone + SSH test)
│   ├── main.tf, providers.tf, versions.tf, variables.tf
│   └── tests/ssh.tftest.hcl
└── docs/
    ├── README.md                    #   Docs hub + OPNsense post-install guide
    ├── ARCHITECTURE.md              #   How the system works (190 lines)
    ├── CONTRIBUTING.md              #   Add new OS template: 8 steps (263 lines)
    └── SECURITY.md                  #   Credentials + hardening checklist (93 lines)
```

## Entry Points

| Purpose | Command | Description |
|---------|---------|-------------|
| Build template | `packer build -var-file="<os>.pkrvars.hcl" .` | Build any OS template |
| Init plugin | `packer init config.pkr.hcl` | Install Proxmox plugin (first time) |
| Test template | `cd terraform-template-test && terraform apply -var=template_id=<id>` | Validate via clone+SSH |
| CI build | Push `*.pkrvars.hcl` to master | Auto-triggers per-OS workflow |

## OS Templates (21)

| OS | File | VM ID | Install Method | Cloud-Init |
|----|------|-------|----------------|------------|
| Ubuntu 26.04 | `ubuntu-26.04.pkrvars.hcl` | 1018 | cloud-init autoinstall | Yes |
| Ubuntu 24.04 | `ubuntu-24.04.pkrvars.hcl` | 1016 | cloud-init autoinstall | Yes |
| Ubuntu 22.04 | `ubuntu-22.04.pkrvars.hcl` | 1015 | cloud-init autoinstall | Yes |
| Ubuntu 20.04 | `ubuntu-20.04.pkrvars.hcl` | 1014 | cloud-init autoinstall | Yes |
| Ubuntu 18.04 | `ubuntu-18.04.pkrvars.hcl` | 1013 | preseed | Yes |
| Debian 13 | `debian-13.pkrvars.hcl` | 1012 | preseed | Yes |
| Debian 12 | `debian-12.pkrvars.hcl` | 1011 | preseed | Yes |
| Debian 11 | `debian-11.pkrvars.hcl` | 1010 | preseed | Yes |
| AlmaLinux 10 | `almalinux-10.pkrvars.hcl` | 1023 | kickstart | Yes |
| AlmaLinux 9 | `almalinux-9.pkrvars.hcl` | 1007 | kickstart | Yes |
| Rocky 10 | `rocky-10.pkrvars.hcl` | 1022 | kickstart | Yes |
| Rocky 9 | `rocky-9.pkrvars.hcl` | 1006 | kickstart | Yes |
| Alpine 3.23 | `alpine-3.23.pkrvars.hcl` | 1021 | answer file | Yes |
| Alpine 3.22 | `alpine-3.22.pkrvars.hcl` | 1020 | answer file | Yes |
| Alpine 3.21 | `alpine-3.21.pkrvars.hcl` | 1009 | answer file | Yes |
| Alpine 3.20 | `alpine-3.20.pkrvars.hcl` | 1008 | answer file | Yes |
| Win Server 2025 | `windows-server-2025.pkrvars.hcl` | 1019 | Autounattend XML | No |
| Win Server 2022 | `windows-server-2022.pkrvars.hcl` | 1004 | Autounattend XML | No |
| Win Server 2019 | `windows-server-2019.pkrvars.hcl` | 1003 | Autounattend XML | No |
| Windows 11 | `windows-11.pkrvars.hcl` | 1005 | Autounattend XML | No |
| Talos 1.13 | `talos-1.13.pkrvars.hcl` | 1024 | dd image via Arch ISO | No |
| Talos 1.12 | `talos-1.12.pkrvars.hcl` | 1002 | dd image via Arch ISO | No |
| OPNsense 25.7 | `opnsense-25.7.pkrvars.hcl` | 1017 | boot_command keystrokes | No |
| VyOS rolling | `vyos-rolling.pkrvars.hcl` | — | boot_command keystrokes | No |

## Core Files

### config.pkr.hcl
Declares Proxmox plugin `v1.2.3` from `github.com/hashicorp/proxmox`.

### variables.pkr.hcl
Defines 38 variables with types, descriptions, and defaults. Key groups:
- **Proxmox connection**: `proxmox_host`, `proxmox_user`, `proxmox_password`, `proxmox_token`
- **VM hardware**: `cpu_type`, `cpu_cores`, `memory`, `disk_size`, `bios`
- **ISO**: `iso_file`, `iso_url`, `iso_checksum`, `iso_download`
- **Network**: `network_adapter`, `network_adapter_vlan`, `network_adapter_firewall`
- **Install**: `boot_command`, `boot_wait`, `http_directory`
- **Communicator**: `ssh_username`/`ssh_password`, `winrm_username`/`winrm_password`
- **Cloud-init**: `cloud_init`, `cloud_init_storage_pool`
- **Windows**: `unattended_content`, `windows_edition`, `windows_language`
- **Packer HTTP**: `packer_http_interface`, `packer_http_bind_address`, `packer_http_port`

### generic.pkr.hcl
Two blocks:
1. **`source "proxmox-iso" "vm"`** — Creates VM on Proxmox, configures hardware, mounts ISO, sets boot order. Uses dynamic blocks for `additional_iso_files` (VirtIO drivers for Windows, CD files for scripts).
2. **`build`** — References the source, runs shell provisioner with `sudo -S` using packer password.

## CI/CD

- **packer.yml**: Reusable workflow (`workflow_call`). Connects to Proxmox via Netbird VPN, runs `packer init` + `packer build`. Concurrency keyed by `vm_id` (no parallel builds of same template).
- **validate-iso.yml**: On PR with `*.pkrvars.hcl` changes. Checks ISO URL reachability and checksum file integrity.
- **Per-OS workflows**: Trigger on push to master when matching `.pkrvars.hcl` changes. Also support `workflow_dispatch` for manual runs.

## Key Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| Packer | 1.15.3 | Build engine |
| packer-plugin-proxmox | v1.2.3 | Proxmox VE integration |
| VirtIO drivers | 0.1.285 | Windows VM paravirtualized drivers |
| Renovate | config:recommended | Automated ISO version updates |
| Netbird | v1.1.0 | VPN tunnel for CI→Proxmox connectivity |

## Quick Reference

```bash
# Build a template locally
packer init config.pkr.hcl
packer build -var-file="ubuntu-24.04.pkrvars.hcl" \
  -var="proxmox_host=IP:8006" \
  -var="proxmox_user=root@pam" \
  -var="proxmox_password=XXX" \
  -var="node=proxmox" \
  -var="vmid=9999" .

# Validate a template's ISO
# (automatically done on PR via validate-iso.yml)
curl -sfIL --max-time 10 "$ISO_URL"
```
