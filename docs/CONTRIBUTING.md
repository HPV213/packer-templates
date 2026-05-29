# Contributing Guide — Adding a New OS Template

This guide walks you through adding a new OS template step by step. No prior Packer knowledge required.

## Prerequisites

- Access to a Proxmox VE server
- [Packer installed](https://developer.hashicorp.com/packer/install) on your machine
- Basic understanding of HCL syntax (key = value, similar to JSON but simpler)

## Quick Reference: OS Families and Install Methods

Each OS family uses a different automated installation method:

| OS Family | Method | Config File Location |
|-----------|--------|---------------------|
| Debian | Preseed | `http/debian/preseed.cfg` |
| Ubuntu (18.04) | Preseed | `http/ubuntu-18.04/preseed.cfg` |
| Ubuntu (20.04+) | Cloud-init autoinstall | `http/ubuntu/user-data` |
| Rocky / AlmaLinux | Kickstart (ks.cfg) | `http/rocky-<ver>/ks.cfg` or `http/almalinux-<ver>/ks.cfg` |
| Alpine | Answer file | `http/alpine/answers` |
| Windows | Unattended XML | `http/windows/Autounattend-*.xml.pkrtpl` |
| Talos | Custom (dd image) | `http/talos/schematic.yaml` |
| OPNsense | Boot command keystrokes | Inline in `.pkrvars.hcl` |
| VyOS | Boot command keystrokes | Inline in `.pkrvars.hcl` |

---

## Step-by-Step: Add a New OS Template

### Step 1: Find the ISO

You need 3 pieces of information:
1. **ISO download URL** — the direct download link
2. **ISO filename** — e.g., `ubuntu-24.04.2-live-server-amd64.iso`
3. **SHA256 checksum** — either the hash directly or a URL to a checksum file

You can usually find these on the OS vendor's download page. Use the **minimal/netinst** ISO when available — it's smaller and faster.

**Tips:**
- For checksum, prefer `file:<checksum_url>` format — Packer will verify automatically
- Example: `iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"`

### Step 2: Create the `.pkrvars.hcl` File

Copy an existing template from the **same OS family** as your new OS. This is important because the `boot_command` and `http_directory` are OS-family specific.

```bash
# Example: adding Ubuntu 28.04 based on Ubuntu 26.04
cp ubuntu-26.04.pkrvars.hcl ubuntu-28.04.pkrvars.hcl
```

### Step 3: Edit the `.pkrvars.hcl` File

Here's what each field means and what to change:

#### All templates need these:

```hcl
# Renovate annotation (helps Renovate bot track versions)
# renovate: datasource=custom.ubuntuLinuxRelease

name           = "ubuntu-28.04-template"     # Template name in Proxmox
iso_file       = "ubuntu-28.04-live-server-amd64.iso"  # Exact ISO filename
iso_url        = "https://releases.ubuntu.com/28.04/ubuntu-28.04-live-server-amd64.iso"  # Download URL
iso_checksum   = "file:https://releases.ubuntu.com/28.04/SHA256SUMS"  # Checksum verification
```

#### Linux templates usually need these:

```hcl
http_directory = "./http/ubuntu"    # Directory with install files (preseed/kickstart)
boot_command   = [...]              # Keystrokes to start automated install
provisioner    = [...]              # Shell commands run after install completes
```

#### Windows templates need these instead:

```hcl
disk_size       = "20G"
communicator    = "winrm"           # Windows uses WinRM, not SSH
http_directory  = ""                # Empty for Windows (uses CD-based install)
cloud_init      = false             # Windows doesn't support cloud-init
boot_command    = []                # Empty — Windows boots from Autounattend.xml

additional_iso_files = [...]        # VirtIO drivers ISO
unattended_content = [...]          # Points to the Autounattend XML template
additional_cd_files = [...]         # Windows setup scripts
```

#### Special templates (OPNsense, VyOS, Talos):

These use inline `boot_command` with keystroke sequences instead of preseed files. See existing templates for reference.

### Step 4: Test Locally

Before pushing, test the build on your machine:

```bash
# Initialize the Packer plugin (first time only)
packer init config.pkr.hcl

# Build the template (replace with your .pkrvars file)
packer build \
  -var-file="ubuntu-28.04.pkrvars.hcl" \
  -var="proxmox_host=192.168.1.10:8006" \
  -var="proxmox_user=root@pam" \
  -var="proxmox_password=yourpassword" \
  -var="node=proxmox" \
  -var="vmid=9999" \
  -force .
```

If the build fails, common issues are:
- **Boot command timing** — increase `boot_wait` or add `<wait>` between keystrokes
- **ISO URL unreachable** — verify the URL in a browser
- **Preseed/kickstart errors** — check the HTTP-served files in `http/`
- **SSH/WinRM timeout** — increase `ssh_timeout` or `winrm_timeout`

### Step 5: Add a GitHub Actions Workflow

Create `.github/workflows/ubuntu-28.04.yml`:

```yaml
name: Ubuntu-28.04
on:
  workflow_dispatch:           # Allow manual trigger
  push:
    branches: [master]
    paths: ['ubuntu-28.04.pkrvars.hcl']  # Auto-build when this file changes

jobs:
  build:
    uses: ./.github/workflows/packer.yml  # Calls the shared workflow
    with:
      name: ubuntu-28.04
      vm_id: 1025              # Unique VM ID (check existing workflows for next available)
    secrets:
      netbird_setup_key: ${{ secrets.NETBIRD_SETUP_KEY }}
      proxmox_host: ${{ secrets.proxmox_host }}
      proxmox_user: ${{ secrets.proxmox_user }}
      proxmox_password: ${{ secrets.proxmox_password }}
```

**Important:** `vm_id` must be unique across all templates. Check existing workflow files for the next available ID.

### Step 6: Update Renovate Config

Add tracking for the new template in `.github/renovate.json5` if the OS family already has a custom datasource entry. For most cases, Renovate will automatically detect the new `.pkrvars.hcl` file.

### Step 7: Update README

Add a row to the overview table in `README.md` following the existing pattern.

### Step 8: Commit and Push

```bash
git checkout -b feature/ubuntu-28.04
git add ubuntu-28.04.pkrvars.hcl .github/workflows/ubuntu-28.04.yml README.md
git commit -m "feat(ubuntu): add Ubuntu 28.04 template"
git push origin feature/ubuntu-28.04
```

The `validate-iso.yml` workflow will automatically check that your ISO URL and checksum are valid on the PR.

---

## Common Tasks

### Update an Existing Template to a New ISO Version

Only the `.pkrvars.hcl` file needs to change:

```hcl
# Before
iso_file     = "ubuntu-24.04.1-live-server-amd64.iso"
iso_url      = "https://old-releases.ubuntu.com/releases/24.04/ubuntu-24.04.1-live-server-amd64.iso"
iso_checksum = "file:https://old-releases.ubuntu.com/releases/24.04/SHA256SUMS"

# After
iso_file     = "ubuntu-24.04.3-live-server-amd64.iso"
iso_url      = "https://old-releases.ubuntu.com/releases/24.04/ubuntu-24.04.3-live-server-amd64.iso"
iso_checksum = "file:https://old-releases.ubuntu.com/releases/24.04/SHA256SUMS"
```

Renovate may do this automatically if the new version matches the allowed update types.

### Add Custom Provisioning

The `provisioner` variable runs shell commands after the OS is installed. Example:

```hcl
provisioner = [
  "cloud-init clean",
  "rm /etc/cloud/cloud.cfg.d/*",
  "apt install -y nginx",       # Install additional packages
  "userdel --remove --force packer"  # Remove build-time user
]
```

**Note:** For Windows, `provisioner` uses PowerShell, not bash.

### Change VM Hardware Defaults

Override any variable from `variables.pkr.hcl` in your `.pkrvars.hcl`:

```hcl
memory     = 4096      # Default: 2048 MB
cpu_cores  = 4         # Default: 2
disk_size  = "32G"     # Default: "5G"
bios       = "ovmf"    # Default: "seabios" (use ovmf for UEFI)
```

### Build Behind a Firewall (SSH Tunnel)

If Proxmox can't reach your build machine's HTTP server:

```bash
# Terminal 1: Start SSH tunnel
ssh -N -R 127.0.0.1:8000:127.0.0.1:8000 root@proxmox

# Terminal 2: Build with HTTP forwarding
packer build \
  -var-file="debian-13.pkrvars.hcl" \
  -var="packer_http_interface=127.0.0.1" \
  -var="packer_http_port=8000" \
  .
```

## Key Concepts Explained

### boot_command

A list of keystrokes sent to the VM console. Special keys:

| Key | Meaning |
|-----|---------|
| `<enter>` | Press Enter |
| `<wait>` | Wait 1 second |
| `<wait5>` | Wait 5 seconds |
| `<wait30>` | Wait 30 seconds |
| `<spacebar>` | Press Space |
| `<esc>` | Press Escape |
| `{{ .HTTPIP }}` | Auto-replaced with Packer's HTTP server IP |
| `{{ .HTTPPort }}` | Auto-replaced with Packer's HTTP server port |

### http_directory

Packer starts a temporary HTTP server serving files from this directory. The OS installer fetches its automated answer file from this server (preseed, kickstart, etc.).

### provisioner

Shell commands executed after the OS is installed and SSH/WinRM is accessible. Runs as the `packer` user via `sudo`.

### communicator

How Packer connects to the VM after installation:
- **`ssh`** (default) — for all Linux templates
- **`winrm`** — for Windows templates

### cloud_init

When `true`, Packer adds a Cloud-Init CDROM drive to the template. This allows Proxmox to inject user-data, network config, and SSH keys when cloning the template. Set to `false` for OS types that don't support Cloud-Init (Windows, OPNsense, VyOS, Talos).
