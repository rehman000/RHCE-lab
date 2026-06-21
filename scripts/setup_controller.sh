#!/bin/bash
# ================================================================
# setup_controller.sh — Provision controller.example.com
# Installs Ansible via pip (no EPEL, no subscription needed)
# ================================================================
set -e

echo "=== Setting up controller.example.com ==="

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
cp /tmp/ansible_key     /home/ansi_user/.ssh/id_rsa
cp /tmp/ansible_key.pub /home/ansi_user/.ssh/id_rsa.pub
chmod 600 /home/ansi_user/.ssh/id_rsa
chmod 644 /home/ansi_user/.ssh/id_rsa.pub
cat /tmp/ansible_key.pub >> /home/ansi_user/.ssh/authorized_keys
chmod 600 /home/ansi_user/.ssh/authorized_keys
chown -R ansi_user:ansi_user /home/ansi_user/.ssh

# ── student user — password only, no SSH key ─────────────────────
id student &>/dev/null || useradd -m -s /bin/bash student
echo 'student:redhat' | chpasswd
echo "student ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/student
chmod 440 /etc/sudoers.d/student

# ── Python3 + Ansible ────────────────────────────────────────
# ANSIBLE_INSTALL env var (set by lab_setup.sh or Vagrantfile):
#   auto  — dnf install ansible-core  (default; Rocky works immediately;
#            RHEL needs subscription or local repo first)
#   pip   — pip install ansible  (full collections, no repo needed)
#   skip  — do NOT install; user installs manually (exam-objective practice)
ANSIBLE_INSTALL="${ANSIBLE_INSTALL:-auto}"

echo "=== Python3 install ==="
dnf install -y python3 --quiet

echo "=== Ansible install mode: ${ANSIBLE_INSTALL} ==="
case "${ANSIBLE_INSTALL}" in
  auto)
    dnf install -y ansible-core --quiet
    ;;
  pip)
    python3 -m ensurepip --upgrade
    python3 -m pip install --quiet ansible
    ;;
  skip)
    echo "--- Skipping Ansible install (manual practice) ---"
    echo "    When ready:  sudo dnf install ansible-core"
    echo "    Or via pip:  pip3 install ansible"
    ;;
  *)
    dnf install -y ansible-core --quiet
    ;;
esac

# ── Deploy Ansible project ────────────────────────────────────
cp -r /tmp/ansible /home/ansi_user/ansible
chown -R ansi_user:ansi_user /home/ansi_user/ansible

# ── Wait for managed nodes to be reachable ────────────────────
NODES=("192.168.56.11" "192.168.56.12" "192.168.56.13" "192.168.56.14" "192.168.56.15")

echo "=== Waiting for managed nodes (max 15 sec each) ==="
for IP in "${NODES[@]}"; do
  ELAPSED=0
  until ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=3 \
            -o BatchMode=yes \
            -i /home/ansi_user/.ssh/id_rsa \
            ansi_user@"$IP" true 2>/dev/null; do
    echo "  Waiting for $IP ..."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $ELAPSED -ge 15 ]; then
      echo "  WARNING: $IP did not respond in 15 sec — skipping."
      break
    fi
  done
  if [ $ELAPSED -lt 15 ]; then
    echo "  $IP is up."
  fi
done

# ── Run initial Ansible playbook (only if Ansible is installed) ──
if [ "${ANSIBLE_INSTALL}" != "skip" ] && command -v ansible-playbook &>/dev/null; then
  echo "=== Running site.yml ==="
  cd /home/ansi_user/ansible
  sudo -u ansi_user ansible-playbook playbooks/site.yml
else
  echo "=== Skipping site.yml (Ansible not installed) ==="
  echo "    Install Ansible, then:  cd ~/ansible && ansible-playbook playbooks/site.yml"
fi

echo "=== Controller setup complete ==="
echo ""
echo "  SSH into controller:  vagrant ssh controller"
echo "  Or from MobaXterm:    ssh ansi_user@192.168.56.10 (key: keys/ansible_key)"
echo "  Root password:        redhat"
echo "  ansi_user password:   redhat"
echo "  student password:   redhat  (no SSH key — use -k flag)"
