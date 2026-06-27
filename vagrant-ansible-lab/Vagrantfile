# -*- mode: ruby -*-
# vi: set ft=ruby :

# ================================================================
# RHCE Practice Lab — VirtualBox + Ansible
# 8 VMs: controller, reposerver, storage-lab, servera-e
#
# OS is selected via lab_setup.sh (recommended) or env var:
#   VAGRANT_LAB_BOX=generic/rocky9 vagrant up
#   VAGRANT_LAB_BOX=generic/rhel9  vagrant up   (default)
#
# BEFORE first `vagrant up`:
#   bash gen_keys.sh          # generates keys/ directory
#
# INTERACTIVE deploy:
#   bash lab_setup.sh         # colored menu, OS choice, repo choice
#
# MANUAL deploy (all VMs):
#   vagrant up
# ================================================================

VAGRANTFILE_API_VERSION = "2"

# ── OS Box Selection ─────────────────────────────────────────
# Set by lab_setup.sh via VAGRANT_LAB_BOX env var.
# Defaults to generic/rhel9 if not set.
LAB_BOX = ENV.fetch("VAGRANT_LAB_BOX", "generic/rhel9")
LAB_BOX_CHECK_UPDATE = ENV.fetch("VAGRANT_BOX_UPDATE", "false") == "true"

MANAGED_NODES = [
  { name: "servera", ip: "192.168.56.11", fqdn: "servera.example.com" },
  { name: "serverb", ip: "192.168.56.12", fqdn: "serverb.example.com" },
  { name: "serverc", ip: "192.168.56.13", fqdn: "serverc.example.com" },
  { name: "serverd", ip: "192.168.56.14", fqdn: "serverd.example.com" },
  { name: "servere", ip: "192.168.56.15", fqdn: "servere.example.com" },
].freeze

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box              = LAB_BOX
  config.vm.box_check_update = LAB_BOX_CHECK_UPDATE
  config.vm.boot_timeout     = 600

  # Disable shared folder — generic boxes have no Guest Additions
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |vb|
    vb.gui          = false
    vb.linked_clone = true  # fast delta-disk cloning
  end

  # ============================================================
  # CONTROLLER  192.168.56.10  2 CPU  2048 MB
  # ============================================================
  config.vm.define "controller" do |m|
    m.vm.hostname = "controller.example.com"
    m.vm.network  "private_network", ip: "192.168.56.10"

    m.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus   = 2
      vb.name   = "rhce-controller"
    end

    # Push pre-generated keypair + Ansible project
    m.vm.provision "file", source: "keys/ansible_key",     destination: "/tmp/ansible_key"
    m.vm.provision "file", source: "keys/ansible_key.pub", destination: "/tmp/ansible_key.pub"
    m.vm.provision "file", source: "ansible",              destination: "/tmp/ansible"
    m.vm.provision "shell", path: "scripts/setup_controller.sh",
      env: { "ANSIBLE_INSTALL" => ENV.fetch("ANSIBLE_INSTALL", "auto") }
  end

  # ============================================================
  # REPO SERVER  192.168.56.20  1 CPU  1024 MB
  # (httpd + createrepo_c — local package mirror)
  # ============================================================
  config.vm.define "reposerver" do |m|
    m.vm.hostname = "reposerver.example.com"
    m.vm.network  "private_network", ip: "192.168.56.20"

    m.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus   = 1
      vb.name   = "rhce-reposerver"
    end

    m.vm.provision "file", source: "keys/ansible_key.pub", destination: "/tmp/ansible_key.pub"
    m.vm.provision "shell", path: "scripts/setup_reposerver.sh"
  end

  # ============================================================
  # STORAGE LAB  192.168.56.30  1 CPU  1024 MB  + 1 GB extra disk
  # (LVM / partition / stratis practice)
  # NOTE: If provisioning fails with storage controller error,
  #       change "SATA Controller" below to "IDE Controller"
  # ============================================================
  config.vm.define "storage-lab" do |m|
    m.vm.hostname = "storage-lab.example.com"
    m.vm.network  "private_network", ip: "192.168.56.30"

    m.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus   = 1
      vb.name   = "rhce-storage-lab"

      disk_path = File.join(File.dirname(__FILE__), "storage_disk.vdi")
      unless File.exist?(disk_path)
        vb.customize ["createmedium", "disk",
          "--filename", disk_path,
          "--size",     1024,
          "--format",   "VDI"]
      end
      vb.customize ["storageattach", :id,
        "--storagectl", "SATA Controller",
        "--port",       1,
        "--device",     0,
        "--type",       "hdd",
        "--medium",     disk_path]
    end

    m.vm.provision "file", source: "keys/ansible_key.pub", destination: "/tmp/ansible_key.pub"
    m.vm.provision "shell", path: "scripts/setup_storage.sh"
  end

  # ============================================================
  # MANAGED NODES  servera-e  192.168.56.11-15  1 CPU  1024 MB
  # ============================================================
  MANAGED_NODES.each do |node|
    config.vm.define node[:name] do |m|
      m.vm.hostname = node[:fqdn]
      m.vm.network  "private_network", ip: node[:ip]

      m.vm.provider "virtualbox" do |vb|
        vb.memory = 1024
        vb.cpus   = 1
        vb.name   = "rhce-#{node[:name]}"
      end

      m.vm.provision "file", source: "keys/ansible_key.pub", destination: "/tmp/ansible_key.pub"
      m.vm.provision "shell", path: "scripts/setup_client.sh",
        env: { "FQDN" => node[:fqdn], "SHORT" => node[:name] }
    end
  end

end
