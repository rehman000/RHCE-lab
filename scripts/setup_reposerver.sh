#!/bin/bash
# ================================================================
# setup_reposerver.sh — Local HTTP package repository server
# Serves packages at http://192.168.56.20/repo/
#
# NOTE: Requires internet access on first boot to download packages.
#       If generic/rhel9 repos are locked, register with Red Hat
#       first, run this provisioner, then configure nodes to use it.
# ================================================================
set -e

echo "=== Setting up reposerver.example.com ==="

# ── Root password ─────────────────────────────────────────────
echo 'root:redhat' | chpasswd

# ── SSH drop-in ───────────────────────────────────────────────
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-lab.conf << 'SSHCFG'
PermitRootLogin yes
PasswordAuthentication yes
SSHCFG
systemctl restart sshd

# ── ansi_user user ──────────────────────────────────────────────
id ansi_user &>/dev/null || useradd -m -s /bin/bash ansi_user
echo 'ansi_user:redhat' | chpasswd
echo "ansi_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansi_user
chmod 440 /etc/sudoers.d/ansi_user

mkdir -p /home/ansi_user/.ssh
chmod 700 /home/ansi_user/.ssh
cp /tmp/ansible_key.pub /home/ansi_user/.ssh/authorized_keys
chmod 600 /home/ansi_user/.ssh/authorized_keys
chown -R ansi_user:ansi_user /home/ansi_user/.ssh

# ── student user — password only ─────────────────────────────────
id student &>/dev/null || useradd -m -s /bin/bash student
echo 'student:redhat' | chpasswd
echo "student ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/student
chmod 440 /etc/sudoers.d/student

# ── Python3 ───────────────────────────────────────────────────
dnf install -y python3 --quiet

# ── Install httpd + createrepo_c ──────────────────────────────
echo "=== Installing httpd and createrepo_c ==="
dnf install -y httpd createrepo_c --quiet

# ── Create repo directory structure ───────────────────────────
mkdir -p /var/www/html/repo/baseos
mkdir -p /var/www/html/repo/appstream

# ── Download curated packages (uses NAT for internet access) ──
echo "=== Downloading packages for local repo ==="

# BaseOS packages
dnf download --destdir=/var/www/html/repo/baseos \
  python3 curl wget vim-minimal net-tools bash-completion \
  --resolve --alldeps 2>/dev/null || {
  echo "WARNING: Some BaseOS packages failed to download — continuing"
}

# AppStream packages
dnf download --destdir=/var/www/html/repo/appstream \
  git tmux httpd mod_ssl firewalld podman skopeo buildah \
  --resolve --alldeps 2>/dev/null || {
  echo "WARNING: Some AppStream packages failed to download — continuing"
}

# ── Build repo metadata ───────────────────────────────────────
echo "=== Building repo metadata ==="
createrepo_c /var/www/html/repo/baseos
createrepo_c /var/www/html/repo/appstream

# ── Enable httpd ──────────────────────────────────────────────
chmod -R 755 /var/www/html/repo/
systemctl enable --now httpd

# Open firewall if running
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=http
  firewall-cmd --reload
fi

echo ""
echo "=== Repo server ready ==="
echo "  BaseOS:    http://192.168.56.20/repo/baseos"
echo "  AppStream: http://192.168.56.20/repo/appstream"
echo ""
echo "  On managed nodes run:"
echo "    ansible-playbook playbooks/configure_local_repo.yml"
echo "=== Reposerver setup complete ==="
