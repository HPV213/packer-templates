# Documentation

## Guides

- [Proxmox Setup](./PROXMOX-SETUP.md) — Create dedicated user + API token with minimal permissions for Packer CI/CD
- [Architecture Overview](./ARCHITECTURE.md) — How the template system works, project structure, CI/CD pipeline
- [Contributing Guide](./CONTRIBUTING.md) — Step-by-step: how to add a new OS template
- [Security Considerations](./SECURITY.md) — Build-time credentials, hardening checklist, secrets management

## OPNsense Post-Install Setup

### Step 1: Create the VM from Template

```bash
cp secrets.template.yml secrets.yml

sudo apt install ansible
ansible-galaxy collection install community.proxmox

ansible-playbook create-opnsense-vm-playbook.yml -e @./secrets.yml
```

### Step 2: Create API Keys

With Ansible:

```bash
cp secrets.template.yml secrets.yml

sudo apt install ansible
ansible-galaxy collection install community.proxmox

# Optional flags (investigate the playbook for details):
#opnsense_api_force: false
#opnsense_api_delete_existing: false

ansible-playbook create-opnsense-api-keys-playbook.yml -e @./secrets.yml

# Store the keys in secrets.xml
```

With Bash script:

```bash
export OPNSENSE_HOST=https://10.10.1.1   # IP of the OPNsense VM
export OPNSENSE_PASSWORD=Secret123
./create-opnsense-api-keys.sh -h
./create-opnsense-api-keys.sh --delete-existing | jq .
{
  "result": "ok",
  "hostname": "OPNsense.internal",
  "key": "iDmG3jCVitsb7jySqxMeDSkkNk5o3Cjo9PwfwlLxttmUjGEZFJpbv70xj3UefXo4zeoHZqa5YYymyqv9",
  "secret": "mB64f2oCAjuu8AdK0t5SXgkIr5XJq5vKGKLibLDeKIrxFElAc2KIjjvfFZmQ5C2L1kF3ov7L1i8APMIj"
}

# Store the keys in secrets.xml
```

### Step 3: Configure OPNsense

```bash
# https://ansible-opnsense.oxl.app/usage/1_install.html
ansible-galaxy collection install oxlorg.opnsense
sudo apt-get install python3-httpx
# https://ansible-opnsense.oxl.app/
ansible-playbook opnsense-playbook.yml -e @./secrets.yml
```

### Important: Post-Deploy Checklist

- [ ] **Change the default password** (template uses `root`/`opnsense`)
- [ ] **Enable the firewall** (it is disabled in the template for build purposes)
- [ ] Create firewall rules for SSH, HTTP, etc. as needed
- [ ] Add ACME certificates for HTTPS if required
