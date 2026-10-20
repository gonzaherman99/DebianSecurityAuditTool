#!/bin/bash

DIRECTORY="/tmp/SecurityAudit/$(date +%a-%b-%d-%Y/%H:%M:%S%p)"

check_for_errors() {
    
    "$@"
    returnC=$?

    if [[ $returnC -eq 0 ]]; then
        echo "Successfully ran [ $* ]"  >&2
    else
        echo "Error: Command [ $* ] returned $returnC" >&2
    fi

    return $returnC
}

world_writable_files() {
     # Find all world-writable files on local filesystems
    WORLD=$(check_for_errors sudo find / -xdev -type f -perm -0002)
    echo "$WORLD" | sudo tee "$DIRECTORY"/World_writable_files.txt > /dev/null
}

users_account_no_password() {
    # Check for users accounts that do not have a password
    PASSWD=$( check_for_errors sudo getent shadow | awk -F: '{if ($2 == "*") print "Account " $1 " has no password"; else if ($2 == "!*") print "Account " $1 " is locked and has no password"; 
    else if ($2 == "!") print "Account " $1 " is locked";  else if ($2 == "") print "Account " $1 " has a null password";}')

    echo "$PASSWD" | sudo tee "$DIRECTORY"/user_account_wopasswd.txt > /dev/null
   }

ssh_unsuccesfull_login() {
     # Check for unsuccesfull SSH login attempts
    SSHLOGIN=$(check_for_errors journalctl -t sshd | grep -e "[Ee].{3}[Rr]" -e "[Ll].{3}[Nn]")
    echo "$SSHLOGIN" | sudo tee "$DIRECTORY"/UnsuccesfullSSHLogin.txt > /dev/null
}

permission_on_critical_files() {
     # Check for permission on critical files 

    criticalFiles=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow" "/etc/sudoers" "/etc/skel" "/etc/login.defs")
    permissionOfCriticalFiles=()

    count=0
    ## loop through above array (quotes are important if your elements may contain spaces)
    for i in "${criticalFiles[@]}"; do
        permission=$(ls -ld "$i" | cut -d' ' -f1)
        permissionOfCriticalFiles+=("$permission")
        echo "${criticalFiles[$count]}": "${permissionOfCriticalFiles[$count]}"
        ((count++));
    done
}

ssh_config() {
    # Check ssh config
    check_for_errors cat /etc/ssh/sshd_config
}

SUID_SGID_binaries() {
    # Check for SUID and SGID binaries

    importantDirs=(/usr/local/sbin /usr/sbin /usr/local/bin /usr/bin /etc /usr/lib /usr/lib64 /usr/lib32 /boot)
    suid_sgid_files=()

    for path in "${importantDirs[@]}"; do
        [[ -d "$path" ]] || continue

        while IFS= read -r -d '' file; do
            suid_sgid_files+=("$file")

            type=""
            [[ -u "$file" ]] && type+="SUID"
            [[ -g "$file" ]] && type+="SGID"

            printf '%-10s %s\n' "$type" "$(stat -c '%A %U:%G %n' "$file")"
        done < <(check_for_errors find "$path" -type f \( -perm -4000 -o -perm -2000 \) -print0)
    done

    echo "Total SUID/SGID files: ${#suid_sgid_files[@]}"
}

auditd_report() {
    # Create auditd reports 
    check_for_errors aureport -u --failed --summary -i
}

upgradbale_packages() {
     #Check for upgradbale packages
    LIST_UPGRADABLE=$(check_for_errors apt list --upgradable)
    echo "$LIST_UPGRADABLE" | sudo tee "$DIRECTORY"/upgradable_packages.txt > /dev/null
}

kernel_errors() {
    #Check for kernel error
    check_for_errors dmesg -l err
}


current_cron_jobs() {
    #See current running cron jobs
    for user in $(check_for_errors cut -f1 -d: /etc/passwd); do crontab -u $user -l; done
}

network_interfaces() {

    #Network Interfaces
    check_for_errors ip -br a
}

processes_by_root() {
     #Check processes run by root
    check_for_errors ps -u root -F
}

password_policies() {
    #Passwrod policies (PAM)
    check_for_errors cat /etc/pam.d/common-password
}

open_sockets() {
    #Show open sockets
    check_for_errors ss -lmi
}

failed_services() {
    # Failed services
    check_for_errors systemctl --state=failed
}

critical_files() {
    check_for_errors find / -maxdepth 3 -name '*.rhosts' -o -name '*.netrc*' -o -name '*.forward*'
}

dirrectories_of_users() {
    while IFS=: read -r f1 f2 f3 f4 f5 f6 f7
    do 
        echo "User $f1 use $f7 shell and stores files in $f6 directory."
    done < /etc/passwd
}



banner_print() {
cat << "EOF"
         #      #        # #######   # ###########
        # #     #        # #      #  #      #
       #   #    #        # #       # #      #
      #######   #        # #       # #      #
     #       #  #        # #      #  #      #
    #         # ########## #######   #      #
EOF
}

check_folder() {
    if [[ -d "$DIRECTORY" ]]; then
        echo "Directory exists"
    else
        mkdir "$DIRECTORY"
    fi
}

menu() {

check_folder

cat << "EOF"
    1) Check for world-writable files
    2) Check for users that do not have passwords
    3) Unsuccesfull SSH login attempts
    4) Check for permission on critical files
    5) Check ssh config
    6) Check for SUID and SGID binaries
    7) Create auditd reports (Failled ones)
    8) Check for upgradbale packages
    9) Check for kernel errors
    10) See current running cron jobs
    11) Current Network Interfaces
    12) Check processes run by root
    13) See Password policies (PAM)
    14) Show open sockets
    15) Failed services
    16) Critical files
EOF

    read -rp "Enter your option: " OPTION

    case $OPTION in
        1)  world_writable_files ;;
        2)  users_account_no_password ;;
        3)  ssh_unsuccesfull_login ;;
        4)  permission_on_critical_files ;;
        5)  ssh_config ;;
        6)  SUID_SGID_binaries ;;
        7)  auditd_report ;;
        8)  upgradbale_packages ;;
        9)  kernel_errors ;;
        10) current_cron_jobs ;;
        11) network_interfaces ;;
        12) processes_by_root ;;
        13) password_policies ;;
        14) open_sockets ;;
        15) failed_services ;;
        16) critical_files ;;
        17) dirrectories_of_users ;;
    *)  echo "Invalid option: $OPTION" >&2 ;;
    esac
    
}

run_as_all() {
    check_folder
    
    world_writable_files
    users_account_no_password
    ssh_unsuccesfull_login
    permission_on_critical_files
    ssh_config
    SUID_SGID_binaries
    auditd_report
    upgradbale_packages
    kernel_errors
    current_cron_jobs
    network_interfaces
    processes_by_root
    password_policies
    open_sockets
    failed_services
    critical_files
    dirrectories_of_users

    return 0
}


SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

case "$1" in
    help|-h|--help)       cat "$SCRIPT_DIR/README" ;;
    version|-v|--version) echo "Version 1.0.0" ;;
    all|-a|--all)         run_as_all ;;
    "")                   banner_print; menu ;;
    *)                    echo "Not known option: $1 (try: $0 help)" >&2; exit 1 ;;
esac