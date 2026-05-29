# Security Considerations

## Build-Time vs Runtime Credentials

This project uses credentials at two stages. Understanding the difference is critical.

### Build-Time Credentials (in this repo)

These credentials are used **only during template build** by Packer. They are NOT meant to be used in production.

| Credential | Location | Purpose | Removed after build? |
|-----------|----------|---------|---------------------|
| `packer` / `packer` (SSH) | `variables.pkr.hcl` defaults | Packer connects to VM to run provisioner | Yes — provisioner deletes the user |
| `packer` / `packer` (WinRM) | `variables.pkr.hcl` defaults | Packer connects to Windows VM | No — Windows keeps Administrator/packer |
| `root` / `packer` (Rocky/Alma kickstart) | `http/*/ks.cfg` | OS installer creates these users | Yes — provisioner locks root, deletes packer |
| `root` / `opnsense` (OPNsense) | `opnsense-25.7.pkrvars.hcl` | OPNsense default login | No — must be changed manually after deploy |
| `vyos` / `vyos` (VyOS) | `vyos-rolling.pkrvars.hcl` | VyOS default login | No — must be changed manually after deploy |

### Template Runtime Credentials

After the template is built and cloned for production use:

| OS Type | Default Login | Action Required |
|---------|--------------|-----------------|
| Linux (cloud-init) | **None** — no user exists | Proxmox cloud-init creates users on clone |
| Windows Server | `Administrator` / `packer` | **Must change password** via Ansible or manually |
| Windows 11 | `Administrator` / `packer` | **Must change password** via Ansible or manually |
| OPNsense | `root` / `opnsense` | **Must change password** immediately after deploy |
| VyOS | `vyos` / `vyos` | **Must change password** immediately after deploy |
| Talos | None (API-based) | No credentials — uses machine config |

## Secrets Management

### Proxmox Credentials

Proxmox API credentials are **never stored in the repo**. They are provided via:

- **CI/CD**: GitHub Actions secrets (`proxmox_host`, `proxmox_user`, `proxmox_password`)
- **Local build**: Environment variables (`PKR_VAR_proxmox_host`, etc.) or a `.pkrvars.hcl` file excluded from git

The `.gitignore` excludes:
```
my.pkrvars.hcl
*.auto.pkrvars.hcl
config.json
```

**Never commit** a file containing Proxmox credentials.

### Netbird VPN Key

The CI/CD pipeline uses Netbird to connect to the Proxmox network. The setup key is stored as a GitHub secret (`NETBIRD_SETUP_KEY`).

## Windows Template Security Notes

The Windows templates have several build-time security relaxations that are necessary for automated installation:

| Setting | Why it's disabled | Risk if left in production |
|---------|-------------------|---------------------------|
| UAC (`EnableLUA=false`) | Allows unattended script execution without prompts | Any process runs with full admin rights |
| WinRM unencrypted | Packer needs to connect without SSL certificates | Credentials sent in cleartext over network |
| RDP NLA disabled | Required for initial remote access setup | Vulnerable to credential relay attacks |
| RDP enabled for all profiles | Allows remote desktop during setup | Attack surface if exposed to untrusted networks |

**These settings MUST be hardened via Ansible (or equivalent) after the template is deployed to production.** At minimum:
1. Enable UAC
2. Configure WinRM over HTTPS
3. Enable RDP Network Level Authentication
4. Restrict RDP firewall rule to specific profiles/networks

## Linux Template Security Notes

### SSH Hardening

Linux templates using cloud-init are pre-configured for secure access:
- Build-time `packer` user is deleted
- Root login is disabled (`passwd -l root`)
- Cloud-init injects SSH keys (no password login)

### SELinux

Rocky and AlmaLinux templates set SELinux to `permissive` mode during build. This should be set to `enforcing` in production via Ansible.

## CI/CD Security

- All Proxmox secrets are stored as GitHub Actions secrets (not in code)
- The `validate-iso.yml` workflow only runs read-only checks (HTTP HEAD requests)
- Build workflows only trigger on push to `master` (protected branch)
- Netbird VPN connection is established only during build and disconnected after

## Reporting Security Issues

If you find a security vulnerability in this project, please report it privately rather than opening a public issue.
