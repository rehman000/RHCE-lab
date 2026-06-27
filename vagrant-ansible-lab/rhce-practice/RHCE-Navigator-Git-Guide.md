# RHCE Exam — ansible-navigator, Git & VS Code Guide

---

## Part 1: ansible-navigator

### What is it?
`ansible-navigator` is the **exam tool** — it replaces `ansible-playbook` on the RHCE EX294 exam.
It runs playbooks inside a container (called an Execution Environment / EE).

### Setup (run once after RHEL registration)
```bash
ansible-playbook playbooks/setup_navigator.yml --limit controller
```
This installs: `git`, `podman`, `ansible-navigator`, pulls the EE image, inits the git repo.

---

### ansible-navigator Commands — Exam Cheat Sheet

#### Run playbooks
```bash
# Run a playbook (exam standard way)
ansible-navigator run playbooks/site.yml

# Run with stdout mode (plain text output like ansible-playbook)
ansible-navigator run playbooks/site.yml -m stdout

# Run against specific hosts
ansible-navigator run playbooks/site.yml -m stdout --limit client1,client2

# Run with vault password
ansible-navigator run playbooks/register_rhel.yml -m stdout --vault-password-file ~/.vault_pass

# Dry run
ansible-navigator run playbooks/site.yml -m stdout --check

# Check syntax
ansible-navigator run playbooks/site.yml --syntax-check -m stdout
```

#### Browse and find modules
```bash
# View module documentation (like ansible-doc)
ansible-navigator doc ansible.builtin.dnf
ansible-navigator doc ansible.posix.firewalld
ansible-navigator doc ansible.builtin.user

# List all available collections in the EE
ansible-navigator collections

# List available EE images
ansible-navigator images

# Inspect an EE image (see what collections are inside)
ansible-navigator images                    # pick image number to inspect
```

#### Work with inventory
```bash
# Browse inventory interactively
ansible-navigator inventory -i inventory/hosts.ini

# List inventory in stdout mode
ansible-navigator inventory -i inventory/hosts.ini -m stdout --list

# Show specific host vars
ansible-navigator inventory -i inventory/hosts.ini -m stdout --host client1
```

#### Other useful commands
```bash
ansible-navigator --version
ansible-navigator --help
ansible-navigator run --help
```

---

### ansible-navigator.yml Configuration File
Placed at `~/ansible/ansible-navigator.yml` — navigator reads it automatically.

```yaml
---
ansible-navigator:
  ansible:
    inventories:
      - /home/ansible/ansible/inventory/hosts.ini
  execution-environment:
    enabled: true
    image: ghcr.io/ansible/community-ee-base:latest   # lab EE
    # On exam use the provided Red Hat EE image instead
    pull:
      policy: missing       # only pull if not already present
  mode: stdout              # plain text output (easier to read)
  logging:
    level: warning
  playbook-artifact:
    enable: false
```

**On the actual exam**, the EE image name will be given to you — replace the image value:
```yaml
    image: registry.redhat.io/ansible-automation-platform/ee-supported-rhel9:latest
```

---

### Using Collections Inside EE
```bash
# See what collections are in your EE
ansible-navigator collections

# Use a collection module in a playbook
# No extra install needed — if it's in the EE it's available
- name: Set SELinux boolean
  ansible.posix.seboolean:          # ansible.posix is in the EE
    name: httpd_can_network_connect
    state: true
    persistent: true
```

---

## Part 2: Git for RHCE Exam

### One-time setup on controller
```bash
git config --global user.name "ansible"
git config --global user.email "ansible@lab.local"
git config --global init.defaultBranch main
```

### Daily Git workflow
```bash
cd ~/ansible

# Check what changed
git status
git diff

# Stage files
git add playbooks/site.yml               # specific file
git add playbooks/                        # whole directory
git add .                                 # everything

# Commit
git commit -m "Add web server playbook"

# View history
git log --oneline
```

### Clone a Git repository
```bash
# Clone from GitHub (exam may give you a URL)
git clone https://github.com/username/repo.git
git clone https://gitlab.example.com/user/rhce-playbooks.git

# Clone into specific directory
git clone https://github.com/user/repo.git ~/myproject

# After cloning
cd repo
ls
```

### Add files and push to remote
```bash
# Set up remote (if not cloned — for a new local repo)
git remote add origin https://github.com/youruser/rhce-lab.git

# Push to remote
git push origin main
git push -u origin main          # -u sets upstream for future pushes

# Pull latest changes
git pull
git pull origin main
```

### Common exam Git tasks
```bash
# Create and switch to new branch
git checkout -b feature/webserver

# Switch back to main
git checkout main

# See all branches
git branch -a

# Check remote URL
git remote -v

# Undo last commit (keep changes)
git reset HEAD~1

# Discard changes to a file
git checkout -- playbooks/site.yml
```

---

## Part 3: VS Code for RHCE

### Required Extensions
Install in VS Code:
- **Ansible** (by Red Hat) — syntax highlighting, linting, navigator integration
- **Remote - SSH** (by Microsoft) — connect directly to controller

### Connect VS Code to the Controller

#### Option A — Remote SSH (Recommended for lab)
1. In Git Bash on Windows: `vagrant ssh-config controller >> ~/.ssh/config`
2. Open VS Code → `Ctrl+Shift+P` → **Remote-SSH: Connect to Host**
3. Pick `controller` from the list
4. Open folder: `/home/ansible/ansible`
5. Now edit playbooks directly on the VM

#### Option B — Edit locally, push via Git
1. Edit playbooks in VS Code on Windows
2. `git add . && git commit -m "update" && git push`
3. On controller: `git pull`

### Configure ansible-navigator in VS Code

The Ansible extension reads `ansible-navigator.yml` automatically.

Open VS Code settings (`Ctrl+,`) and search for "ansible":
- **Ansible > Navigator: Path** → set to `/usr/local/bin/ansible-navigator`
- **Ansible > Python: Interpreter Path** → `/usr/bin/python3`
- **Ansible > Execution Environment: Enabled** → ✓ checked
- **Ansible > Execution Environment: Image** → `ghcr.io/ansible/community-ee-base:latest`

### Run playbooks from VS Code Terminal
```bash
# Open integrated terminal: Ctrl+`
cd ~/ansible
ansible-navigator run playbooks/site.yml -m stdout
```

### Useful VS Code keyboard shortcuts for playbooks
| Shortcut | Action |
|---|---|
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+`` ` | Open terminal |
| `Ctrl+Space` | Autocomplete (YAML/Ansible) |
| `Shift+Alt+F` | Format document |
| `Ctrl+/` | Comment/uncomment line |
| `F5` | Run (if task configured) |

---

## Part 4: Full Exam Workflow Example

```bash
# 1. SSH into controller
vagrant ssh controller

# 2. Go to ansible project
cd ~/ansible

# 3. Create a new playbook
vi playbooks/webserver.yml

# 4. Check syntax before running
ansible-navigator run playbooks/webserver.yml --syntax-check -m stdout

# 5. Dry run
ansible-navigator run playbooks/webserver.yml --check -m stdout

# 6. Run it
ansible-navigator run playbooks/webserver.yml -m stdout

# 7. Verify
ansible nodes -m command -a "systemctl status httpd"

# 8. Save to git
git add playbooks/webserver.yml
git commit -m "Add webserver playbook"
git push
```

---

## Part 5: Key Differences — ansible-playbook vs ansible-navigator

| Feature | ansible-playbook | ansible-navigator |
|---|---|---|
| Runs in | Local environment | Container (EE) |
| Output | Always stdout | Interactive TUI by default |
| Stdout mode | Always | Add `-m stdout` |
| Module docs | `ansible-doc module` | `ansible-navigator doc module` |
| Collections | Locally installed | Inside EE image |
| Config file | `ansible.cfg` | `ansible-navigator.yml` + `ansible.cfg` |
| Exam tool | Old exams | **Current RHCE EX294** |

> **Exam tip**: Always use `-m stdout` with ansible-navigator so output looks familiar and is easier to read during the exam.
