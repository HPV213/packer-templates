# Architecture Overview

## What is Packer?

Packer is a tool by HashiCorp that builds machine images (VM templates) automatically. Instead of manually installing an OS, configuring it, and converting it to a template — Packer does it all from code.

**How it works in 3 steps:**
1. Packer creates a temporary VM on Proxmox
2. Installs the OS using automated answers (no human input)
3. Converts the VM to a reusable template and deletes the temporary VM

## Project Structure

```
packer-templates/
├── config.pkr.hcl              # Packer plugin configuration (Proxmox plugin)
├── variables.pkr.hcl           # All configurable variables with defaults
├── generic.pkr.hcl             # Shared VM build logic (used by ALL templates)
│
├── *.pkrvars.hcl               # OS-specific variable files (one per template)
│
├── http/                       # Automated installation files served via HTTP
│   ├── alpine/answers          # Alpine answer file
│   ├── debian/preseed.cfg      # Debian preseed
│   ├── ubuntu/user-data        # Ubuntu cloud-init autoinstall
│   ├── ubuntu-18.04/preseed.cfg
│   ├── rocky-9/ks.cfg          # Rocky Linux kickstart
│   ├── rocky-10/ks.cfg
│   ├── almalinux-9/ks.cfg      # AlmaLinux kickstart
│   ├── almalinux-10/ks.cfg
│   ├── windows/                # Windows unattended install XML templates
│   │   ├── Autounattend-server.xml.pkrtpl
│   │   └── Autounattend-win11.xml.pkrtpl
│   ├── windows-scripts/        # Windows post-install scripts
│   │   └── setup.ps1
│   ├── talos/schematic.yaml    # Talos Linux extensions config
│   └── vyos/qemu-guest-agent.sh
│
├── .github/workflows/          # CI/CD pipelines
│   ├── packer.yml              # Reusable build workflow
│   ├── validate-iso.yml        # PR validation
│   └── <os>.yml                # Per-OS workflow triggers
│
├── terraform-template-test/    # Template validation via Terraform
│   ├── main.tf                 # Clone template + test SSH connectivity
│   └── tests/ssh.tftest.hcl
│
└── docs/                       # Documentation
```

## How the Template System Works

The project uses a **shared source + variable files** pattern:

```
config.pkr.hcl    →  "Load the Proxmox plugin"
generic.pkr.hcl   →  "Define HOW to build a VM" (shared by all OS)
ubuntu-24.04.pkrvars.hcl  →  "Ubuntu-specific settings"
debian-13.pkrvars.hcl     →  "Debian-specific settings"
windows-server-2025.pkrvars.hcl  →  "Windows-specific settings"
```

### File Roles

| File | Role | Do I need to edit it? |
|------|------|----------------------|
| `config.pkr.hcl` | Declares the Proxmox Packer plugin version | Only to upgrade plugin |
| `variables.pkr.hcl` | Defines all possible variables and their defaults | Only to add new variables |
| `generic.pkr.hcl` | The actual build logic — creates VM, installs OS, provisions | Rarely (only for new features) |
| `*.pkrvars.hcl` | OS-specific values (ISO URL, boot commands, provisioner) | **Yes — this is what you edit** |
| `http/*` | Unattended install files (preseed, kickstart, etc.) | When adding a new OS family |

### Build Flow (Step by Step)

```
1. You run: packer build -var-file="ubuntu-24.04.pkrvars.hcl" .

2. Packer reads config.pkr.hcl
   → Installs the Proxmox plugin

3. Packer reads variables.pkr.hcl
   → Knows all available variables and defaults

4. Packer reads ubuntu-24.04.pkrvars.hcl
   → Overrides defaults with Ubuntu-specific values

5. Packer reads generic.pkr.hcl
   → Uses the "proxmox-iso" source block to:
     a. Connect to Proxmox API
     b. Create a temporary VM
     c. Download/mount the ISO
     d. Start the HTTP server (serves http/ folder)
     e. Boot the VM and send boot_command keystrokes
     f. The OS installer fetches preseed/kickstart from the HTTP server
     g. Wait for SSH/WinRM connection
     h. Run provisioner commands
     i. Convert VM to template
     j. Cleanup

6. Done — template is ready on Proxmox
```

## CI/CD Pipeline

### On Push to `master`

Each OS has its own workflow file (e.g., `.github/workflows/ubuntu-24.04.yml`). When a `.pkrvars.hcl` file changes on master, the corresponding workflow triggers:

```
Push to master → ubuntu-24.04.pkrvars.hcl changed
  → .github/workflows/ubuntu-24.04.yml triggers
    → calls .github/workflows/packer.yml (reusable workflow)
      → connects to Proxmox via Netbird VPN
      → runs packer build
      → disconnects from VPN
```

### On Pull Request

The `validate-iso.yml` workflow checks that ISO URLs are reachable and checksums match. This prevents merging broken templates.

```
PR with *.pkrvars.hcl changes
  → validate-iso.yml triggers
    → checks iso_url is reachable (HTTP HEAD)
    → checks iso_checksum URL is reachable
    → checks iso_file is listed in the checksum file
```

### Per-OS Workflow Pattern

Each OS workflow is a thin wrapper:

```yaml
# .github/workflows/ubuntu-24.04.yml
on:
  push:
    branches: [master]
    paths: ['ubuntu-24.04.pkrvars.hcl']   # Only triggers when THIS file changes

jobs:
  build:
    uses: ./.github/workflows/packer.yml   # Calls the shared workflow
    with:
      name: ubuntu-24.04                   # Template name
      vm_id: 1016                          # Proxmox VM ID for the template
```

## Renovate Integration

[Renovate](https://github.com/renovatebot/renovate) automatically creates PRs when new ISO versions are released.

### How it works

1. Renovate scans `.pkrvars.hcl` files using custom regex managers
2. Detects current ISO versions from filenames and URLs
3. Checks custom datasources (HTML scraping of download pages)
4. Creates a PR when a new version is found

### Renovate policies

| OS | Major | Minor | Patch |
|----|-------|-------|-------|
| Debian | Blocked | Allowed | Allowed |
| Ubuntu | Blocked | Allowed | Allowed |
| AlmaLinux | Blocked | Allowed | Allowed |
| Rocky | Blocked | Allowed | Allowed |
| Alpine | Blocked | Blocked | Allowed |
| OPNsense | Blocked | Allowed | Allowed |
| Talos | Blocked | Blocked | Allowed |
| Packer plugin | — | Allowed | Allowed |

Major version bumps are blocked to prevent accidental breaking changes. They must be done manually.

## Terraform Template Test

The `terraform-template-test/` directory contains a Terraform configuration that:

1. Clones a built template on Proxmox
2. Waits for the VM to boot and get an IP
3. Tests SSH connectivity
4. Verifies the template is functional

Run manually to validate a template after building:

```bash
cd terraform-template-test
terraform init
terraform apply -var=template_id=1016   # Use the VM ID of your template
```
