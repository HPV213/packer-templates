# Proxmox Setup for Packer CI/CD

This guide explains how to create a dedicated Proxmox user with minimal permissions for Packer to build VM templates. No `root` access needed.

## Why a Dedicated User?

- **Principle of least privilege** — Packer only needs to create VMs and manage templates, not administer the entire cluster
- **Auditability** — All Packer actions are logged under a dedicated identity
- **Token revocation** — If the token is leaked, revoke it without affecting other users
- **No root in CI** — GitHub Actions secrets never contain the root password

## Required Permissions

Packer performs these operations during a build:

| Operation | Packer Action | Required Privilege |
|-----------|--------------|-------------------|
| Create VM | Create temporary VM on node | `VM.Allocate` |
| Configure hardware | Set CPU, RAM, disk, network, VGA, BIOS | `VM.Config.CPU`, `.Memory`, `.Disk`, `.Network`, `.HWType`, `.Options` |
| Mount ISO | Attach ISO file to VM | `Datastore.Audit`, `Datastore.AllocateSpace` |
| Download ISO (upload) | Upload ISO file to PVE node | `Datastore.Upload` |
| Download ISO (from URL) | Download ISO via URL to PVE node | `Datastore.AllocateTemplate`, `Sys.AccessNetwork` |
| Boot VM | Start the VM | `VM.PowerMgmt` |
| Send keystrokes | Type boot commands via VNC | `VM.Console` |
| Cloud-Init | Add Cloud-Init CDROM drive | `VM.Config.Cloudinit` |
| Convert to template | Turn VM into a reusable template | `VM.Allocate` |
| Assign to pool | Place template in resource pool | `Pool.Allocate` |
| Discover nodes | List available Proxmox nodes | `Sys.Audit` |

## Setup via CLI (Recommended)

SSH into your Proxmox node and run:

### 1. Create the User

```bash
pveum user add packer@pve -comment "Packer CI/CD builder"
```

### 2. Create the Custom Role

```bash
pveum role add PackerBuilder -privs \
  "VM.Allocate VM.Clone VM.Config.CPU VM.Config.Cloudinit \
   VM.Config.Disk VM.Config.HWType VM.Config.Memory \
   VM.Config.Network VM.Config.Options VM.Console \
   VM.Monitor VM.PowerMgmt \
   Datastore.AllocateSpace Datastore.Audit Datastore.AllocateTemplate Datastore.Upload \
   Pool.Allocate Sys.Audit Sys.AccessNetwork"
```

### 3. Assign Permissions

**Important:** If using `--privsep 1` (default), permissions must be assigned to BOTH the user AND the token separately. See [Token Privilege Separation](#token-privilege-separation-privsep) below.

Replace `proxmox` with your actual node name. Check with `pvesh get /nodes`.

```bash
# Node — create, configure, boot VMs
pveum acl modify /nodes/proxmox -user packer@pve -role PackerBuilder

# Storage: local — ISO files
pveum acl modify /storage/local -user packer@pve -role PackerBuilder

# Storage: local-lvm — VM disks + cloud-init
pveum acl modify /storage/local-lvm -user packer@pve -role PackerBuilder

# Pool — assign templates to pool
pveum acl modify /pool/templates -user packer@pve -role PackerBuilder
```

If using `--privsep 1`, also run for the token (note single quotes around `!`):

```bash
pveum acl modify /nodes -token 'packer@pve!ci' -role PackerBuilder
pveum acl modify /storage/local -token 'packer@pve!ci' -role PackerBuilder
pveum acl modify /storage/local-lvm -token 'packer@pve!ci' -role PackerBuilder
pveum acl modify /pool/templates -token 'packer@pve!ci' -role PackerBuilder
```

### 4. Create the Pool (if it doesn't exist)

```bash
pveum pool add templates -comment "VM templates built by Packer"
```

### 5. Create API Token

```bash
pveum user token add packer@pve ci --privsep 0
```

Output:

```
┌─────────────┬──────────────────────────────────────┐
│ key         │ value                                │
├─────────────┼──────────────────────────────────────┤
│ full-tokenid│ packer@pve!ci                        │
│ value       │ xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx │
└─────────────┴──────────────────────────────────────┘
```

**Save the `value` immediately** — it is shown only once.

> `--privsep 0` means the token inherits all permissions from the user.
> With `--privsep 1`, you must assign permissions to the token separately.

## Setup via Web UI

### Create User
1. **Datacenter → Permissions → Users → Add**
2. User name: `packer`, Realm: `PVE authentication server`, set password
3. Click **Add**

### Create Custom Role
1. **Datacenter → Permissions → Roles → Create**
2. Name: `PackerBuilder`
3. Tick these privileges:

```
☑ Datastore.AllocateSpace
☑ Datastore.Audit
☑ Datastore.AllocateTemplate
☑ Datastore.Upload
☑ Pool.Allocate
☑ Sys.AccessNetwork
☑ Sys.Audit
☑ VM.Allocate
☑ VM.Clone
☑ VM.Config.Cloudinit
☑ VM.Config.CPU
☑ VM.Config.Disk
☑ VM.Config.HWType
☑ VM.Config.Memory
☑ VM.Config.Network
☑ VM.Config.Options
☑ VM.Console
☑ VM.Monitor
☑ VM.PowerMgmt
```

### Assign Permissions
**Datacenter → Permissions → Add** — create 4 entries:

| Path | User | Role |
|------|------|------|
| `/nodes/<your-node-name>` | `packer@pve` | `PackerBuilder` |
| `/storage/local` | `packer@pve` | `PackerBuilder` |
| `/storage/local-lvm` | `packer@pve` | `PackerBuilder` |
| `/pool/templates` | `packer@pve` | `PackerBuilder` |

### Create Pool
1. **Datacenter → Pool → Create**
2. Pool ID: `templates`

### Create API Token
1. **Datacenter → Permissions → API Tokens → Add**
2. User: `packer@pve`, Token ID: `ci`
3. **Uncheck** "Privilege Separation"
4. Click **Add** → Copy the secret

## Configure GitHub Secrets

In your GitHub repo: **Settings → Secrets and variables → Actions**

| Secret | Value | Notes |
|--------|-------|-------|
| `proxmox_host` | `192.168.1.10:8006` | Proxmox API address (IP:port) |
| `proxmox_user` | `packer@pve` | User without token ID (workflow auto-appends `!ci`) |
| `proxmox_password` | *(empty)* | Not used when using token |
| `proxmox_token` | `ci=TOKEN_SECRET` | Format: `tokenid=uuid` (workflow splits this) |
| `NETBIRD_SETUP_KEY` | `a1b2c3d4-...` | Netbird setup key for VPN |
| `NETBIRD_MANAGEMENT_URL` | `https://netbird.example.com` | Netbird self-hosted URL |

The workflow automatically splits `proxmox_token` into the correct format for Packer:
- Packer `username` = `packer@pve!ci` (user + token ID)
- Packer `token` = just the UUID secret

## Verify Setup

### Check Permissions

```bash
# List all permissions for packer user
pveum acl list | grep packer
```

### Test API Token

```bash
# Test authentication — should return JSON with version info
curl -sk \
  -H "Authorization: PVEAPIToken=packer@pve!ci=YOUR_TOKEN_SECRET" \
  https://localhost:8006/api2/json/version

# Test node access — should return node info
curl -sk \
  -H "Authorization: PVEAPIToken=packer@pve!ci=YOUR_TOKEN_SECRET" \
  https://localhost:8006/api2/json/nodes

# Test storage access — should list ISO files
curl -sk \
  -H "Authorization: PVEAPIToken=packer@pve!ci=YOUR_TOKEN_SECRET" \
  https://localhost:8006/api2/json/nodes/proxmox/storage/local/content
```

If you get JSON responses instead of `403 Permission check failed`, the setup is correct.

### Test Build

Run a manual build via GitHub Actions:
1. Go to **Actions → Ubuntu-24.04** (or any template)
2. Click **Run workflow → Run workflow**
3. Monitor the build logs for permission errors

## Token Privilege Separation (privsep)

When creating an API token, Proxmox offers two modes:

| Mode | Flag | Behavior |
|------|------|----------|
| **Separated** | `--privsep 1` (default) | Token has its own ACL, independent from user. Must grant permissions to token explicitly. Effective permissions = intersection of (user perms ∩ token perms). |
| **Inherited** | `--privsep 0` | Token inherits all permissions from user. No separate ACL needed. |

### Check current mode

```bash
pveum user token list packer@pve
# If privsep column = 1 → must grant permissions to token separately
# If privsep column = 0 → token already has user permissions
```

### Granting permissions to token (privsep 1)

Every path the token needs to access must be granted separately. Use single quotes because `!` has special meaning in shell:

```bash
pveum acl modify /nodes -token 'packer@pve!ci' -role PackerBuilder
pveum acl modify /storage/local -token 'packer@pve!ci' -role PackerBuilder
pveum acl modify /storage/local-lvm -token 'packer@pve!ci' -role PackerBuilder
pveum acl modify /pool/templates -token 'packer@pve!ci' -role PackerBuilder
```

### Switch to inherited mode (privsep 0)

For convenience in trusted environments:

```bash
pveum user token modify packer@pve ci --privsep 0
```

### Verify token permissions

```bash
pveum user permissions packer@pve --tokenid ci
# Or check specific path:
pveum user token permissions packer@pve ci /storage/local
```

## Troubleshooting

### `403 Permission check failed`

```bash
# Check which permissions are assigned
pveum acl list | grep packer

# Common missing permissions:
# - /nodes/<node> → needs PackerBuilder role
# - /storage/local-lvm → forgot to assign for disk storage
# - /pool/templates → pool doesn't exist yet
```

### `506 Proxy Error` during ISO upload

The `Datastore.Upload` privilege is required when `iso_download_pve = "true"` (downloading ISO directly on the PVE node). Also ensure the `local` storage has enough space. If downloading ISOs from URL (`download-url` API), you also need `Datastore.AllocateTemplate` and `Sys.AccessNetwork`.

### Token not working

- Verify format: `packer@pve!ci` (user!tokenid)
- Check that "Privilege Separation" was unchecked when creating the token
- Token secrets are shown only once — if lost, delete and recreate

### `no such pool` error

```bash
# Create the pool if it doesn't exist
pveum pool add templates -comment "VM templates built by Packer"
```
