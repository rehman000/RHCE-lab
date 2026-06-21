# RHCE Practice Lab — Vagrant + VirtualBox + Ansible

**generic/rhel9** — 8 VMs, FQDN hostnames, exam-realistic layout

```
192.168.6.10   controller.example.com   2 CPU / 2048 MB  ← Ansible control node
192.168.6.11   servera.example.com      1 CPU / 1024 MB
192.168.6.12   serverb.example.com      1 CPU / 1024 MB
192.168.6.13   serverc.example.com      1 CPU / 1024 MB
192.168.6.14   serverd.example.com      1 CPU / 1024 MB
192.168.6.15   servere.example.com      1 CPU / 1024 MB
192.168.6.20   reposerver.example.com   1 CPU / 1024 MB  ← local httpd repo
192.168.6.30   storage-lab.example.com  1 CPU / 1024 MB  ← extra 1 GB disk
```

**Users on all VMs:**
| User      | Password    | SSH Key | Purpose                        |
|-----------|-------------|---------|--------------------------------|
| root      | redhat      | yes     | Root access (MobaXterm/SSH)    |
| ansible   | redhat      | yes     | Ansible automation user        |
| test_user | redhat      | **NO**  | Practice `ansible -k` flag     |

---

## Prerequisites

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads)
- Git Bash (Windows) or any bash terminal

---

## Project Structure

```
vagrant-ansible-lab/
├── Vagrantfile                       ← 8 VMs, linked_clone, FQDNs
├── gen_keys.sh                       ← Run once before first vagrant up
├── lab_setup.sh                      ← Interactive colored deploy/destroy/patch menu
├── keys/                             ← Generated SSH keypair (gitignored)
├── scripts/
│   ├── setup_client.sh               ← Managed nodes (servera-e)
│   ├── setup_controller.sh           ← Users/keys + Ansible install (auto/pip/skip)
│   ├── setup_reposerver.sh           ← httpd + createrepo_c
│   └── setup_storage.sh              ← Storage practice node
└── ansible/
    ├── ansible.cfg
    ├── ansible-navigator.yml             ← Execution-environment config (optional)
    ├── inventory/hosts.ini
    ├── vars/rh_credentials.yml.template  ← Copy + fill in for Red Hat registration
    └── playbooks/
        ├── site.yml                  ← Initial node config (auto-run)
        ├── configure_local_repo.yml  ← Point nodes to local repo server
        ├── register_rhel.yml         ← Red Hat registration (Ansible + vault path)
        ├── unregister_rhel.yml       ← Run before vagrant destroy (Ansible + vault path)
        └── setup_navigator.yml       ← Optional: ansible-navigator + EE on controller
```

---

## Quick Start

### 1. Generate SSH keys (once)

```bash
bash gen_keys.sh
```

### 2a. Interactive deploy/destroy (recommended)

```bash
# Fix Windows line endings first (run once):
sed -i 's/\r$//' lab_setup.sh

bash lab_setup.sh
```

**Step 1 — OS Selection (shown first, every time):**
```
1) RHEL 9   (generic/rhel9)  ← Real Red Hat, needs subscription for full repos
                                Best for RHCE exam practice
2) Rocky 9  (generic/rocky9) ← Free RHEL clone, full repos without subscription
                                Good for class / general practice
```

**Step 2 — Main Menu:**
```
1) Deploy / Start Lab Elements
2) Destroy Lab Elements
3) Update Boxes / Patch OS
4) Exit
```

---

**Option 1 — Deploy Menu:**

```
a) Standard Lab            — controller + servera/b/c/d/e         (6 VMs)
b) Full Lab with Repo      — standard + reposerver                 (7 VMs)
c) Storage Practice Lab    — standard + storage-lab                (7 VMs)
d) Complete Lab            — all 8 VMs
e) Repo Server Only        — reposerver alone
f) Custom Selection        — y/N prompt for each individual VM
```

**Ansible Installation on Controller** (asked whenever `controller` is part of the deploy):
```
1) ansible-core via dnf   (recommended)
   Rocky 9: works immediately
   RHEL 9:  needs subscription or local repo first
2) ansible (full) via pip
   No repo/subscription needed -- installs from PyPI
3) Skip -- install manually   (exam-objective practice)
   Controller boots with users/keys ready, no ansible
   Then practice: sudo dnf install ansible-core
```

After deploy (when controller is included) the script asks how to configure repos:
```
1) Register with Red Hat subscription-manager
2) Use local repo server (reposerver.example.com)
3) Skip — configure manually later
```

> If you chose **Skip** for Ansible above, option 1 here registers every deployed VM directly via `subscription-manager` (prompts once for your Red Hat username/password) — no ansible-vault or ansible-playbook required. If Ansible was installed, option 1 instead walks you through the ansible-vault + `register_rhel.yml` flow (see **Repository Configuration** below).

---

**Option 2 — Destroy Menu:**

```
a) Destroy EVERYTHING      — vagrant destroy -f on all VMs
                             also deletes storage_disk.vdi
b) Custom Selection        — y/N prompt per VM, then final confirmation
```

Custom destroy asks each VM one by one:
```
Destroy 'controller'?   [y/N]:
Destroy 'reposerver'?   [y/N]:
Destroy 'storage-lab'?  [y/N]:   ← also removes storage_disk.vdi if yes
Destroy 'servera'?      [y/N]:
Destroy 'serverb'?      [y/N]:
Destroy 'serverc'?      [y/N]:
Destroy 'serverd'?      [y/N]:
Destroy 'servere'?      [y/N]:
```

> **TIP:** If you registered with Red Hat, unregister before destroying to free up subscription slots:
> - **With ansible:** `vagrant ssh controller -c "cd ~/ansible && ansible-playbook playbooks/unregister_rhel.yml --ask-vault-pass"`
> - **Without ansible:** `vagrant ssh <vm> -c "sudo subscription-manager remove --all && sudo subscription-manager unregister"`

---

**Option 3 — Update Boxes / Patch OS:**
```
a) Update Vagrant box template   (affects FUTURE VMs only)
b) Patch OS on running VMs       (dnf update -- affects CURRENT VMs)
c) Cancel
```

**a) Update box template:**
```
a) Selected OS only  (whichever OS you picked at startup)
b) Both RHEL 9 and Rocky 9
c) Cancel
```
Existing VMs are untouched — destroy + up to rebuild from the new template. Clean old versions with `vagrant box prune`.

**b) Patch OS on running VMs:**
Prompts y/N for each VM (must already be running), then asks how to set up repos before patching:
```
1) Register with Red Hat subscription-manager   (RHEL — prompts for username/password directly, no ansible-vault needed)
   Ensure Rocky BaseOS/AppStream/Extras enabled  (Rocky — no prompt needed)
2) Use local repo server (reposerver.example.com)
3) Skip -- repos already configured
```
Then runs `sudo dnf -y update` on each selected, running VM. This path never touches Ansible or the vault file — it's plain `vagrant ssh` + `subscription-manager`/`dnf`.

### 2b. Manual deploy

```bash
# RHEL 9 (default)
vagrant up
vagrant up controller servera serverb serverc serverd servere

# Rocky 9
VAGRANT_LAB_BOX=generic/rocky9 vagrant up
VAGRANT_LAB_BOX=generic/rocky9 vagrant up controller servera serverb serverc serverd servere

# Specific VM
vagrant up reposerver
```

### 3. Verify

```bash
vagrant ssh controller
cd ~/ansible
ansible nodes -m ping               # ping all 5 managed nodes
ansible-playbook playbooks/site.yml # re-run if needed
```

---

## Repository Configuration

### Option A — Red Hat Subscription (Ansible installed)

```bash
# On controller:
cd ~/ansible
cp vars/rh_credentials.yml.template vars/rh_credentials.yml
# Edit rh_credentials.yml with your developer account credentials
ansible-vault encrypt vars/rh_credentials.yml
ansible-playbook playbooks/register_rhel.yml --ask-vault-pass
```

Unregister before destroying:
```bash
ansible-playbook playbooks/unregister_rhel.yml --ask-vault-pass
```

### Option A2 — Red Hat Subscription (Ansible skipped)

If you chose **Skip** during the Ansible Installation prompt, don't use the vault/playbook flow above — there's no `ansible-vault` binary on the controller. Instead use `lab_setup.sh` itself:

- **At deploy time:** main menu → `1) Deploy` → repo choice `1) Register with Red Hat` — prompts for your username/password directly and loops `subscription-manager register` over every VM in the deployment via plain `vagrant ssh`.
- **Later, on already-running VMs:** main menu → `3) Update Boxes / Patch OS` → `b) Patch OS on running VMs` → repo choice `1`.

Both paths are pure bash + `vagrant ssh` + `subscription-manager` — no Ansible required.

To unregister manually per VM:
```bash
vagrant ssh <vm> -c "sudo subscription-manager remove --all && sudo subscription-manager unregister"
```

### Option B — Local Repo Server

Deploy `reposerver` (deploy style `b` or `d`), then either let `lab_setup.sh` configure it automatically (repo choice `2`), or manually:
```bash
vagrant ssh controller -c "cd ~/ansible && ansible-playbook playbooks/configure_local_repo.yml"
```

### Option C — Skip

Configure `/etc/yum.repos.d/` manually on each VM later.

---

## Optional: ansible-navigator

After the controller is registered (Option A or A2 above), you can additionally set up `ansible-navigator` plus an execution environment:

```bash
vagrant ssh controller
cd ~/ansible
ansible-playbook playbooks/setup_navigator.yml --limit controller
```

Installs git, podman, and `ansible-navigator` (via pip), pulls the `community-ee-base` execution environment image, and initializes a git repo for the ansible project (`vars/rh_credentials.yml` is gitignored so credentials never get committed).
