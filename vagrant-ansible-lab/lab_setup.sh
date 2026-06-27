#!/bin/bash
# ================================================================
# lab_setup.sh -- Interactive RHCE Lab Manager
# IMPORTANT (Windows/Git Bash): fix line endings first:
#   sed -i 's/\r$//' lab_setup.sh && bash lab_setup.sh
# ================================================================

NC='\033[0m'
BOLD_WHITE='\033[1;37m'
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_RED='\033[1;31m'
BOLD_MAGENTA='\033[1;35m'
TEXT_CYAN='\033[0;36m'
TEXT_GREEN='\033[0;32m'
TEXT_YELLOW='\033[0;33m'

if [ ! -f "Vagrantfile" ]; then
  echo -e "${BOLD_RED}ERROR: Run from the vagrant-ansible-lab directory.${NC}"
  exit 1
fi

if [ ! -f "keys/ansible_key" ]; then
  echo -e "${BOLD_YELLOW}SSH keys not found. Generating now...${NC}"
  bash gen_keys.sh
fi

# ── Helper: is a given VM currently running? ────────────────────
is_running() {
  vagrant status "$1" 2>/dev/null | grep -q "running (virtualbox)"
}

# ── OS Selection ──────────────────────────────────────────────
clear
echo -e "${BOLD_MAGENTA}>>> Starting RHCE LAB SETUP...${NC}\n"
echo -e "${BOLD_CYAN}==================================================${NC}"
echo -e "${BOLD_WHITE}    Select Operating System                       ${NC}"
echo -e "${BOLD_CYAN}==================================================${NC}"
echo -e "${BOLD_CYAN}1)${NC} ${BOLD_WHITE}RHEL 9${NC}   (generic/rhel9)"
echo -e "   ${TEXT_YELLOW}Real Red Hat -- needs subscription for full repos${NC}"
echo -e "   ${TEXT_YELLOW}Best for RHCE exam practice${NC}"
echo ""
echo -e "${BOLD_CYAN}2)${NC} ${BOLD_WHITE}Rocky 9${NC}  (generic/rocky9)"
echo -e "   ${TEXT_GREEN}Free RHEL clone -- full repos without subscription${NC}"
echo -e "   ${TEXT_GREEN}Good for class / general practice${NC}"
echo -e "${BOLD_CYAN}==================================================${NC}"
read -rp "$(echo -e "${BOLD_YELLOW}Choose OS [1-2] (default: 1): ${NC}")" os_choice

case $os_choice in
  2)
    export VAGRANT_LAB_BOX="generic/rocky9"
    OS_LABEL="Rocky Linux 9"
    ;;
  *)
    export VAGRANT_LAB_BOX="generic/rhel9"
    OS_LABEL="RHEL 9"
    ;;
esac

echo -e "\n${BOLD_GREEN}Selected: ${BOLD_WHITE}${OS_LABEL}${NC} (${VAGRANT_LAB_BOX})\n"

# ── Main menu ─────────────────────────────────────────────────
echo -e "${BOLD_CYAN}==================================================${NC}"
echo -e "${BOLD_WHITE}    RHCE Dynamic Lab Environment Manager          ${NC}"
echo -e "${BOLD_WHITE}    OS: ${BOLD_GREEN}${OS_LABEL}${NC}"
echo -e "${BOLD_CYAN}==================================================${NC}"
echo -e "${BOLD_GREEN}1)${NC} Deploy / Start Lab Elements"
echo -e "${BOLD_RED}2)${NC} Destroy Lab Elements"
echo -e "${BOLD_CYAN}3)${NC} Update Boxes / Patch OS"
echo -e "${BOLD_WHITE}4)${NC} Exit"
echo -e "${BOLD_CYAN}==================================================${NC}"
read -rp "$(echo -e "${BOLD_YELLOW}Choose an option [1-4]: ${NC}")" main_choice

case $main_choice in

  # ============================================================
  # DEPLOY
  # ============================================================
  1)
    echo ""
    echo -e "${BOLD_WHITE}Deployment Modes:${NC}"
    echo -e "${BOLD_CYAN}a)${NC} Standard Lab            -- controller + servera/b/c/d/e (6 VMs)"
    echo -e "${BOLD_CYAN}b)${NC} Full Lab with Repo      -- standard + reposerver (7 VMs)"
    echo -e "${BOLD_CYAN}c)${NC} Storage Practice Lab    -- standard + storage-lab (7 VMs)"
    echo -e "${BOLD_CYAN}d)${NC} Complete Lab            -- all 8 VMs"
    echo -e "${BOLD_CYAN}e)${NC} Repo Server Only"
    echo -e "${BOLD_CYAN}f)${NC} Custom Selection"
    echo ""
    read -rp "$(echo -e "${BOLD_YELLOW}Select deployment option [a-f]: ${NC}")" style_choice

    declare -a active_servers=()

    case $style_choice in
      a)
        echo -e "\n${BOLD_GREEN}Deploying standard RHCE lab...${NC}"
        echo -e "${TEXT_YELLOW}  Nodes first, controller last${NC}"
        active_servers=("servera" "serverb" "serverc" "serverd" "servere" "controller")
        ;;
      b)
        echo -e "\n${BOLD_GREEN}Deploying full lab with repo server...${NC}"
        echo -e "${TEXT_YELLOW}  Nodes first, controller last${NC}"
        active_servers=("reposerver" "servera" "serverb" "serverc" "serverd" "servere" "controller")
        ;;
      c)
        echo -e "\n${BOLD_GREEN}Deploying storage practice lab...${NC}"
        echo -e "${TEXT_YELLOW}  Nodes first, controller last${NC}"
        active_servers=("servera" "serverb" "serverc" "serverd" "servere" "storage-lab" "controller")
        ;;
      d)
        echo -e "\n${BOLD_GREEN}Deploying complete lab (all 8 VMs)...${NC}"
        echo -e "${TEXT_YELLOW}  Nodes first, controller last${NC}"
        active_servers=("reposerver" "storage-lab" "servera" "serverb" "serverc" "serverd" "servere" "controller")
        ;;
      e)
        echo -e "\n${BOLD_GREEN}Deploying repo server only...${NC}"
        active_servers=("reposerver")
        ;;
      f)
        echo ""
        echo -e "${BOLD_CYAN}==================================================${NC}"
        echo -e "${BOLD_WHITE} Type 'y' for each VM you want to spin up:       ${NC}"
        echo -e "${BOLD_YELLOW} Note: controller always deploys last             ${NC}"
        echo -e "${BOLD_CYAN}==================================================${NC}"
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'controller'?   [y/N]: ${NC}")" want_controller
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'reposerver'?   [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("reposerver")
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'storage-lab'?  [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("storage-lab")
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'servera'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("servera")
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'serverb'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("serverb")
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'serverc'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("serverc")
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'serverd'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("serverd")
        read -rp "$(echo -e "${TEXT_CYAN}Deploy 'servere'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && active_servers+=("servere")
        # Controller always goes last
        [[ "$want_controller" =~ ^[Yy]$ ]] && active_servers+=("controller")

        if [ ${#active_servers[@]} -eq 0 ]; then
          echo -e "${BOLD_RED}No VMs selected. Exiting.${NC}"
          exit 0
        fi
        ;;
      *)
        echo -e "${BOLD_RED}Invalid selection.${NC}"
        exit 1
        ;;
    esac

    # ── Ansible install preference (only when controller will deploy) ──
    if [[ " ${active_servers[*]} " =~ " controller " ]]; then
      echo ""
      echo -e "${BOLD_CYAN}==================================================${NC}"
      echo -e "${BOLD_WHITE}   Ansible Installation on Controller             ${NC}"
      echo -e "${BOLD_CYAN}==================================================${NC}"
      echo -e "${BOLD_CYAN}1)${NC} ${BOLD_WHITE}ansible-core via dnf${NC}  ${TEXT_GREEN}(recommended)${NC}"
      echo -e "   ${TEXT_YELLOW}Rocky 9: works immediately${NC}"
      echo -e "   ${TEXT_YELLOW}RHEL 9:  needs subscription or local repo first${NC}"
      echo -e "${BOLD_CYAN}2)${NC} ${BOLD_WHITE}ansible (full) via pip${NC}"
      echo -e "   ${TEXT_YELLOW}No repo/subscription needed -- installs from PyPI${NC}"
      echo -e "${BOLD_CYAN}3)${NC} ${BOLD_WHITE}Skip -- install manually${NC}  ${BOLD_RED}(exam-objective practice)${NC}"
      echo -e "   ${TEXT_YELLOW}Controller boots with users/keys ready, no ansible${NC}"
      echo -e "   ${TEXT_YELLOW}Then practice:  sudo dnf install ansible-core${NC}"
      echo -e "${BOLD_CYAN}==================================================${NC}"
      read -rp "$(echo -e "${BOLD_YELLOW}Choose [1-3] (default: 1): ${NC}")" ansible_choice
      case $ansible_choice in
        2) export ANSIBLE_INSTALL="pip"  ;;
        3) export ANSIBLE_INSTALL="skip" ;;
        *) export ANSIBLE_INSTALL="auto" ;;
      esac
      echo -e "${TEXT_CYAN}Ansible install mode: ${BOLD_WHITE}${ANSIBLE_INSTALL}${NC}\n"
    fi

    echo -e "\n${BOLD_GREEN}Starting VMs: ${BOLD_WHITE}${active_servers[*]}${NC}\n"
    for vm in "${active_servers[@]}"; do
      echo -e "${BOLD_CYAN}>>> Bringing up: $vm${NC}"
      vagrant up "$vm"
    done

    # ── Update /etc/hosts on controller ─────────────────────
    if [[ " ${active_servers[*]} " =~ " controller " ]]; then
      echo ""
      echo -e "${BOLD_CYAN}==================================================${NC}"
      echo -e "${BOLD_WHITE}   Updating /etc/hosts on controller...           ${NC}"
      echo -e "${BOLD_CYAN}==================================================${NC}"

      local_entries=$(mktemp)

      cntl_ip=$(vagrant ssh controller -c "hostname -I" 2>/dev/null \
        | tr ' ' '\n' | grep -v '^10\.0\.2\.' | head -n1 | tr -d '\r\n')
      [ -n "$cntl_ip" ] && {
        echo "$cntl_ip controller.example.com controller" >> "$local_entries"
        echo -e "${TEXT_GREEN}  controller.example.com -> $cntl_ip${NC}"
      }

      for vm in "${active_servers[@]}"; do
        [ "$vm" = "controller" ] && continue
        ip_addr=$(vagrant ssh "$vm" -c "hostname -I" 2>/dev/null \
          | tr ' ' '\n' | grep -v '^10\.0\.2\.' | head -n1 | tr -d '\r\n')
        if [ -n "$ip_addr" ]; then
          echo "$ip_addr ${vm}.example.com ${vm}" >> "$local_entries"
          echo -e "${TEXT_GREEN}  ${vm}.example.com -> $ip_addr${NC}"
        else
          echo -e "${BOLD_YELLOW}  WARNING: Could not get IP for $vm${NC}"
        fi
      done

      hosts_block=$(cat "$local_entries")
      vagrant ssh controller -c "
        sudo sed -i '/# --- RHCE LAB SERVERS START ---/,/# --- RHCE LAB SERVERS END ---/d' /etc/hosts
        printf '\n# --- RHCE LAB SERVERS START ---\n%s\n# --- RHCE LAB SERVERS END ---\n' '$hosts_block' | sudo tee -a /etc/hosts > /dev/null
      " 2>/dev/null
      rm -f "$local_entries"

      echo -e "${BOLD_GREEN}  /etc/hosts updated on controller.${NC}"
      echo -e "${BOLD_CYAN}==================================================${NC}"

      # ── Repo choice ───────────────────────────────────────
      echo ""
      echo -e "${BOLD_CYAN}==================================================${NC}"
      echo -e "${BOLD_WHITE}   Repository / Subscription Configuration        ${NC}"
      echo -e "${BOLD_CYAN}==================================================${NC}"
      echo -e "${BOLD_CYAN}1)${NC} Register with Red Hat (subscription-manager)"
      echo -e "   ${TEXT_YELLOW}Requires developer account at access.redhat.com${NC}"
      echo -e "${BOLD_CYAN}2)${NC} Use local repo server (reposerver.example.com)"
      if [[ ! " ${active_servers[*]} " =~ " reposerver " ]]; then
        echo -e "   ${BOLD_RED}(reposerver NOT deployed -- deploy it first)${NC}"
      fi
      echo -e "${BOLD_CYAN}3)${NC} Skip -- configure manually later"
      echo ""
      read -rp "$(echo -e "${BOLD_YELLOW}Choose repo method [1-3]: ${NC}")" repo_choice

      case $repo_choice in
        1)
          if [[ "$ANSIBLE_INSTALL" == "skip" ]]; then
            echo ""
            echo -e "${BOLD_YELLOW}Ansible was skipped -- registering directly via subscription-manager${NC}"
            echo -e "${BOLD_YELLOW}(no ansible-vault / ansible-playbook needed).${NC}"
            read -rp "$(echo -e "${TEXT_CYAN}Red Hat username: ${NC}")" RH_USER
            read -rsp "$(echo -e "${TEXT_CYAN}Red Hat password: ${NC}")" RH_PASS
            echo ""
            for vm in "${active_servers[@]}"; do
              echo -e "${BOLD_CYAN}>>> Registering $vm with Red Hat...${NC}"
              vagrant ssh "$vm" -c "sudo subscription-manager register --username='$RH_USER' --password='$RH_PASS' --auto-attach --force" 2>&1
            done
            unset RH_PASS
            echo -e "${BOLD_GREEN}Direct registration complete.${NC}"
            echo -e "${TEXT_YELLOW}To unregister later (no ansible needed), per VM:${NC}"
            echo -e "  ${TEXT_CYAN}vagrant ssh <vm> -c 'sudo subscription-manager remove --all && sudo subscription-manager unregister'${NC}"
          else
            echo ""
            echo -e "${BOLD_WHITE}Red Hat Registration Steps:${NC}"
            echo -e "  1. ${TEXT_CYAN}vagrant ssh controller${NC}"
            echo -e "  2. ${TEXT_CYAN}cd ~/ansible${NC}"
            echo -e "     ${TEXT_CYAN}cp vars/rh_credentials.yml.template vars/rh_credentials.yml${NC}"
            echo -e "     ${TEXT_CYAN}# Edit file with your Red Hat credentials${NC}"
            echo -e "     ${TEXT_CYAN}ansible-vault encrypt vars/rh_credentials.yml${NC}"
            echo -e "  3. ${TEXT_CYAN}ansible-playbook playbooks/register_rhel.yml --ask-vault-pass${NC}"
            echo ""
            echo -e "  ${BOLD_YELLOW}Before destroying VMs, unregister first:${NC}"
            echo -e "  ${TEXT_CYAN}ansible-playbook playbooks/unregister_rhel.yml --ask-vault-pass${NC}"
          fi
          ;;
        2)
          if [[ " ${active_servers[*]} " =~ " reposerver " ]]; then
            echo -e "\n${BOLD_GREEN}Configuring nodes to use local repo server...${NC}"
            vagrant ssh controller -c "cd /home/ansible/ansible && ansible-playbook playbooks/configure_local_repo.yml" 2>/dev/null
            echo -e "${BOLD_GREEN}Local repo configured.${NC}"
          else
            echo -e "${BOLD_YELLOW}Reposerver not deployed. Redeploy with option b or d.${NC}"
          fi
          ;;
        3)
          echo -e "${TEXT_CYAN}Skipped. Configure repos manually on the controller.${NC}"
          ;;
      esac
    fi

    echo ""
    echo -e "${BOLD_CYAN}==================================================${NC}"
    echo -e "${BOLD_GREEN}   Lab deployment complete!                       ${NC}"
    echo -e "${BOLD_CYAN}==================================================${NC}"
    echo -e "${BOLD_WHITE} VM Access:${NC}"
    echo -e "  ${TEXT_CYAN}vagrant ssh controller${NC}"
    echo -e "  ${TEXT_CYAN}vagrant ssh servera${NC}"
    echo ""
    echo -e "${BOLD_WHITE} MobaXterm / SSH:${NC}"
    echo -e "  Host: ${TEXT_CYAN}192.168.6.10${NC}  User: ${TEXT_CYAN}ansible${NC}  Key: ${TEXT_CYAN}keys/ansible_key${NC}"
    echo -e "  All passwords: ${TEXT_CYAN}redhat${NC}"
    echo -e "  test_user: password ${TEXT_CYAN}redhat${NC} (no SSH key -- use -k)"
    echo -e "${BOLD_CYAN}==================================================${NC}"
    ;;

  # ============================================================
  # DESTROY
  # ============================================================
  2)
    echo ""
    echo -e "${BOLD_RED}==================================================${NC}"
    echo -e "${BOLD_WHITE}            VM Destruction Options                ${NC}"
    echo -e "${BOLD_RED}==================================================${NC}"
    echo -e "${BOLD_CYAN}a)${NC} ${BOLD_RED}Destroy EVERYTHING${NC} (entire lab)"
    echo -e "${BOLD_CYAN}b)${NC} Custom selection"
    echo ""
    read -rp "$(echo -e "${BOLD_YELLOW}Select teardown strategy [a/b]: ${NC}")" destroy_style

    case $destroy_style in
      a)
        echo -e "\n${BOLD_RED}WARNING: This destroys all lab VMs and the storage disk.${NC}"
        echo -e "${BOLD_YELLOW}TIP: Unregister RHEL subscriptions first if registered:${NC}"
        echo -e "  ${TEXT_CYAN}With ansible:    vagrant ssh controller -c 'cd ~/ansible && ansible-playbook playbooks/unregister_rhel.yml --ask-vault-pass'${NC}"
        echo -e "  ${TEXT_CYAN}Without ansible: vagrant ssh <vm> -c 'sudo subscription-manager remove --all && sudo subscription-manager unregister'${NC}"
        echo ""
        read -rp "$(echo -e "${BOLD_YELLOW}Confirm destroy all? (y/n): ${NC}")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          vagrant destroy -f
          rm -f storage_disk.vdi
          echo -e "${BOLD_GREEN}All VMs destroyed.${NC}"
        else
          echo -e "${BOLD_YELLOW}Aborted.${NC}"
        fi
        ;;
      b)
        echo ""
        echo -e "${BOLD_RED}==================================================${NC}"
        echo -e "${BOLD_WHITE} Type 'y' for each VM you want to DESTROY:       ${NC}"
        echo -e "${BOLD_RED}==================================================${NC}"
        declare -a targets=()
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'controller'?   [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("controller")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'reposerver'?   [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("reposerver")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'storage-lab'?  [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("storage-lab")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'servera'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("servera")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'serverb'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("serverb")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'serverc'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("serverc")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'serverd'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("serverd")
        read -rp "$(echo -e "${TEXT_YELLOW}Destroy 'servere'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && targets+=("servere")

        if [ ${#targets[@]} -eq 0 ]; then
          echo -e "${BOLD_YELLOW}No VMs selected.${NC}"
          exit 0
        fi

        echo -e "\n${BOLD_RED}Targets: ${BOLD_WHITE}${targets[*]}${NC}"
        read -rp "$(echo -e "${BOLD_YELLOW}Confirm? (y/n): ${NC}")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          for t in "${targets[@]}"; do
            echo -e "${BOLD_RED}Destroying $t...${NC}"
            vagrant destroy -f "$t"
            [ "$t" = "storage-lab" ] && rm -f storage_disk.vdi
          done
          echo -e "${BOLD_GREEN}Selected VMs destroyed.${NC}"
        else
          echo -e "${BOLD_YELLOW}Aborted.${NC}"
        fi
        ;;
      *)
        echo -e "${BOLD_RED}Invalid option.${NC}"
        ;;
    esac
    ;;

  # ============================================================
  # UPDATE BOXES / PATCH OS
  # ============================================================
  3)
    echo ""
    echo -e "${BOLD_CYAN}==================================================${NC}"
    echo -e "${BOLD_WHITE}   Update / Patch Manager                         ${NC}"
    echo -e "${BOLD_CYAN}==================================================${NC}"
    echo -e "${BOLD_CYAN}a)${NC} Update Vagrant box template  ${TEXT_YELLOW}(affects FUTURE VMs only)${NC}"
    echo -e "${BOLD_CYAN}b)${NC} Patch OS on running VMs       ${TEXT_YELLOW}(dnf update -- affects CURRENT VMs)${NC}"
    echo -e "${BOLD_CYAN}c)${NC} Cancel"
    echo -e "${BOLD_CYAN}==================================================${NC}"
    read -rp "$(echo -e "${BOLD_YELLOW}Choose [a-c]: ${NC}")" patch_menu_choice

    case $patch_menu_choice in

      # -------------------------------------------------------
      # a) Update box template only (old behaviour)
      # -------------------------------------------------------
      a)
        echo ""
        echo -e "${BOLD_CYAN}==================================================${NC}"
        echo -e "${BOLD_WHITE}   Box Update -- Pull Latest Box Template          ${NC}"
        echo -e "${BOLD_CYAN}==================================================${NC}"
        echo -e "${BOLD_CYAN}a)${NC} Selected OS only  (${OS_LABEL} -- ${VAGRANT_LAB_BOX})"
        echo -e "${BOLD_CYAN}b)${NC} Both RHEL 9 and Rocky 9"
        echo -e "${BOLD_CYAN}c)${NC} Cancel"
        echo ""
        read -rp "$(echo -e "${BOLD_YELLOW}Choose [a-c]: ${NC}")" update_choice

        case $update_choice in
          a)
            echo -e "\n${BOLD_GREEN}Updating ${VAGRANT_LAB_BOX}...${NC}"
            vagrant box update --box "${VAGRANT_LAB_BOX}"
            echo -e "${BOLD_GREEN}Done. Remove old versions: ${TEXT_CYAN}vagrant box prune${NC}"
            echo -e "${TEXT_YELLOW}Note: existing VMs are untouched -- destroy+up to rebuild from the new template.${NC}"
            ;;
          b)
            echo -e "\n${BOLD_GREEN}Updating generic/rhel9...${NC}"
            vagrant box update --box generic/rhel9
            echo -e "\n${BOLD_GREEN}Updating generic/rocky9...${NC}"
            vagrant box update --box generic/rocky9
            echo -e "\n${BOLD_GREEN}Both updated. Remove old: ${TEXT_CYAN}vagrant box prune${NC}"
            ;;
          *)
            echo -e "${BOLD_YELLOW}Cancelled.${NC}"
            ;;
        esac
        ;;

      # -------------------------------------------------------
      # b) Patch OS on running VMs -- repo setup + dnf update
      # -------------------------------------------------------
      b)
        echo ""
        echo -e "${BOLD_CYAN}==================================================${NC}"
        echo -e "${BOLD_WHITE}   Select VMs to Patch (must be running)          ${NC}"
        echo -e "${BOLD_CYAN}==================================================${NC}"
        declare -a patch_targets=()
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'controller'?   [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("controller")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'reposerver'?   [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("reposerver")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'storage-lab'?  [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("storage-lab")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'servera'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("servera")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'serverb'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("serverb")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'serverc'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("serverc")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'serverd'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("serverd")
        read -rp "$(echo -e "${TEXT_CYAN}Patch 'servere'?      [y/N]: ${NC}")" c
        [[ "$c" =~ ^[Yy]$ ]] && patch_targets+=("servere")

        if [ ${#patch_targets[@]} -eq 0 ]; then
          echo -e "${BOLD_YELLOW}No VMs selected.${NC}"
          exit 0
        fi

        echo ""
        echo -e "${BOLD_CYAN}==================================================${NC}"
        echo -e "${BOLD_WHITE}   Repository Setup Before Patching                ${NC}"
        echo -e "${BOLD_WHITE}   Current OS: ${BOLD_GREEN}${OS_LABEL}${NC}"
        echo -e "${BOLD_CYAN}==================================================${NC}"
        if [[ "$VAGRANT_LAB_BOX" == *rhel* ]]; then
          echo -e "${BOLD_CYAN}1)${NC} Register with Red Hat subscription-manager  ${TEXT_YELLOW}(adds BaseOS/AppStream)${NC}"
        else
          echo -e "${BOLD_CYAN}1)${NC} Ensure Rocky BaseOS/AppStream/Extras enabled  ${TEXT_YELLOW}(default mirrors)${NC}"
        fi
        echo -e "${BOLD_CYAN}2)${NC} Use local repo server  ${TEXT_YELLOW}(reposerver.example.com)${NC}"
        echo -e "${BOLD_CYAN}3)${NC} Skip -- repos already configured"
        echo -e "${BOLD_CYAN}==================================================${NC}"
        read -rp "$(echo -e "${BOLD_YELLOW}Choose [1-3]: ${NC}")" repo_patch_choice

        case $repo_patch_choice in
          1)
            if [[ "$VAGRANT_LAB_BOX" == *rhel* ]]; then
              read -rp "$(echo -e "${TEXT_CYAN}Red Hat username: ${NC}")" RH_USER
              read -rsp "$(echo -e "${TEXT_CYAN}Red Hat password: ${NC}")" RH_PASS
              echo ""
              for vm in "${patch_targets[@]}"; do
                if is_running "$vm"; then
                  echo -e "${BOLD_CYAN}>>> Registering $vm with Red Hat...${NC}"
                  vagrant ssh "$vm" -c "sudo subscription-manager register --username='$RH_USER' --password='$RH_PASS' --auto-attach --force" 2>&1
                else
                  echo -e "${BOLD_YELLOW}  $vm not running -- skipped${NC}"
                fi
              done
            else
              for vm in "${patch_targets[@]}"; do
                if is_running "$vm"; then
                  echo -e "${BOLD_CYAN}>>> Ensuring Rocky repos enabled on $vm...${NC}"
                  vagrant ssh "$vm" -c "sudo dnf config-manager --set-enabled baseos appstream extras 2>/dev/null || true"
                else
                  echo -e "${BOLD_YELLOW}  $vm not running -- skipped${NC}"
                fi
              done
            fi
            ;;
          2)
            repo_cmd="sudo tee /etc/yum.repos.d/lab-baseos.repo > /dev/null << 'RPEOF'
[lab-baseos]
name=Lab BaseOS
baseurl=http://192.168.56.20/repo/baseos
enabled=1
gpgcheck=0
RPEOF
sudo tee /etc/yum.repos.d/lab-appstream.repo > /dev/null << 'RPEOF'
[lab-appstream]
name=Lab AppStream
baseurl=http://192.168.56.20/repo/appstream
enabled=1
gpgcheck=0
RPEOF"
            for vm in "${patch_targets[@]}"; do
              if is_running "$vm"; then
                echo -e "${BOLD_CYAN}>>> Pointing $vm at local repo server...${NC}"
                vagrant ssh "$vm" -c "$repo_cmd"
              else
                echo -e "${BOLD_YELLOW}  $vm not running -- skipped${NC}"
              fi
            done
            ;;
          3)
            echo -e "${TEXT_CYAN}Skipping repo setup.${NC}"
            ;;
          *)
            echo -e "${BOLD_RED}Invalid choice -- skipping repo setup.${NC}"
            ;;
        esac

        echo ""
        echo -e "${BOLD_CYAN}==================================================${NC}"
        echo -e "${BOLD_WHITE}   Patching OS (dnf update)                        ${NC}"
        echo -e "${BOLD_CYAN}==================================================${NC}"
        for vm in "${patch_targets[@]}"; do
          if is_running "$vm"; then
            echo -e "${BOLD_CYAN}>>> $vm: dnf update -y${NC}"
            vagrant ssh "$vm" -c "sudo dnf -y update"
          else
            echo -e "${BOLD_YELLOW}  $vm not running -- skipped${NC}"
          fi
        done
        echo -e "${BOLD_GREEN}Patch run complete.${NC}"
        ;;

      *)
        echo -e "${BOLD_YELLOW}Cancelled.${NC}"
        ;;
    esac
    ;;

  4)
    echo -e "${BOLD_WHITE}Exiting. Keep automating!${NC}"
    exit 0
    ;;

  *)
    echo -e "${BOLD_RED}Invalid option.${NC}"
    exit 1
    ;;
esac
