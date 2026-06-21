#!/bin/bash
# ================================================================
# setup_storage.sh — Storage practice node
# Extra 1 GB VDI disk is attached by VirtualBox (see Vagrantfile)
# Use this VM to practice: LVM, partitions, Stratis, VDO, NFS, iSCSI
# ================================================================
set -e

echo "=== Setting up storage-lab.example.com ==="

# ── Hostname ─────────────────────────────────────────────────
hostnamectl set-hostname "storage-lab.example.com"

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

# ── Show available storage (practice reference) ───────────────
echo ""
echo "=== Storage devices on this VM ==="
lsblk
echo ""
echo "  Extra disk for practice: look for /dev/sdb (or /dev/vdb)"
echo "  Practice tasks: fdisk, parted, pvcreate, lvcreate, mkfs, mount"
echo "=== storage-lab setup complete ==="
