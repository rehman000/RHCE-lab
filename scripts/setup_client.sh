#!/bin/bash
# ================================================================
# setup_client.sh — Provision managed nodes (servera-e)
# Called by Vagrantfile with env: FQDN, SHORT
# ================================================================
set -e

FQDN="${FQDN:-$(hostname)}"
SHORT="${SHORT:-$(hostname -s)}"

echo "=== Setting up managed node: $FQDN ==="

# ── Hostname ─────────────────────────────────────────────────
hostnamectl set-hostname "$FQDN"

# ── Root password ─────────────────────────────────────────────
echo 'root:redhat' | chpasswd

# ── SSH: allow root login + password auth ─────────────────────
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-lab.conf << 'SSHCFG'
PermitRootLogin yes
PasswordAuthentication yes
SSHCFG
systemctl restart sshd

# ── ansi_user user (SSH key auth) ───────────────────────────────
id ansi_user &>/dev/null || useradd -m -s /bin/bash ansi_user
echo 'ansi_user:redhat' | chpasswd
echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user
chmod 440 /etc/sudoers.d/ansi_user

mkdir -p /home/ansi_user/.ssh
chmod 700 /home/ansi_user/.ssh
cp /tmp/ansible_key.pub /home/ansi_user/.ssh/authorized_keys
chmod 600 /home/ansi_user/.ssh/authorized_keys
chown -R ansi_user:ansi_user /home/ansi_user/.ssh

# ── student user — PASSWORD ONLY, no SSH key ─────────────────────
# Purpose: practice `ansible -k` (ask-pass) scenarios
id student &>/dev/null || useradd -m -s /bin/bash student
echo 'student:redhat' | chpasswd
echo "student ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/student
chmod 440 /etc/sudoers.d/student

# ── Python3 (required by Ansible modules) ─────────────────────
dnf install -y python3 --quiet

echo "=== $FQDN setup complete ==="
