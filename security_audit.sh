#!/bin/bash

DIRECTORY="/tmp/SecurityAudit"

if [[ -d "$DIRECTORY" ]]; then
    echo "Direcotry exists"
else
    mkdir /tmp/SecurityAudit
fi

argument=$1

main() {

    # Find all world-writable files on local filesystems
    sudo find / -xdev -type f -perm -0002 2>/dev/null 1>"$DIRECTORY"/World_writable_files.txt

    # Check for users accounts that do not have a password
 
    sudo getent shadow | awk -F: '{if ($2 == "*") print "Account " $1 " has no password"; else if ($2 == "!*") print "Account " $1 " is locked and has no password"; 
    else if ($2 == "!") print "Account " $1 " is locked";}' > "$DIRECTORY"/Accounts_status.txt
   
    # Check for unsuccesfull SSH login attempts

    journalctl -t sshd | grep -e "[Ee].{3}[Rr]" -e "[Ll].{3}[Nn]" > "$DIRECTORY"/UnsuccesfullSSHLogin.txt


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

    # Check ssh config

    cat /etc/ssh/ssh_config

    # Check for SUID and SGID binaries

    importantDirs=(/usr/local/sbin /usr/sbin /usr/local/bin /usr/bin /etc /usr/lib /usr/lib64 /usr/lib32 /boot)
    suid_sgid_files=()

    for path in "${importantDirs[@]}"; do
        [[ -d "$path" ]] || continue

        while IFS= read -r -d '' file; do
            suid_sgid_files+=("$file")

            type=""
            [[ -u "$file" ]] && type+="SUID "
            [[ -g "$file" ]] && type+="SGID"

            printf '%-10s %s\n' "$type" "$(stat -c '%A %U:%G %n' "$file")"
        done < <(find "$path" -type f \( -perm -4000 -o -perm -2000 \) -print0 2>/dev/null)
    done

    echo "Total SUID/SGID files: ${#suid_sgid_files[@]}"

    


    # Create auditd reports 

}

while true ; do
    if [[ "$argument" == "help" ]]; then
        echo "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean convallis libero sit amet neque pulvinar semper. Nullam laoreet condimentum quam, non auctor lorem 
        scelerisque in. Duis elementum consequat diam, eget auctor sem rhoncus in. Aliquam vel pharetra dui. Sed volutpat ex ex, quis fermentum justo dignissim sit amet. Proin 
        vestibulum lacus id nunc luctus interdum. Etiam auctor egestas nulla id feugiat. Aenean facilisis tellus non lectus posuere, eget facilisis turpis tempor. Mauris odio quam, 
        venenatis et rutrum quis, fringilla vel eros. Proin a fermentum nibh. Suspendisse sagittis enim ut lectus volutpat, non suscipit tellus sagittis."
        break;
    elif [[ "$argument" == "version" ]]; then   
        echo "Version 1.0.0"
    else 
        main
        break;
    fi
done
