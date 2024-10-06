#!/usr/bin/env bash

disable_ubuntu_report() {
    ubuntu-report send no
    apt remove ubuntu-report -y
}

remove_appcrash_popup() {
    apt remove apport apport-gtk -y
}

remove_snaps() {
    while [ "$(snap list | wc -l)" -gt 0 ]; do
        for snap in $(snap list  | grep -v base$ | grep -v snapd$ | tail -n +2 | cut -d ' ' -f 1); do
            snap remove --purge "$snap"
        done
        for snap in $(snap list  |  tail -n +2 | cut -d ' ' -f 1); do
            snap remove --purge "$snap"
        done
    done
    systemctl stop snapd
    systemctl disable snapd
    systemctl mask snapd
    apt purge snapd -y
    rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd
    for userpath in /home/*; do
        rm -rf $userpath/snap
    done
    cat <<-EOF | tee /etc/apt/preferences.d/nosnap.pref
	Package: snapd
	Pin: release a=*
	Pin-Priority: -10
	EOF
}

update_system() {
    apt update && apt upgrade -y
}

cleanup() {
    apt autoremove -y
}

setup_flathub() {
    apt install flatpak -y
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    apt install --install-suggests gnome-software -y
}

restore_firefox() {
	add-apt-repository ppa:mozillateam/ppa -y
	echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' > /etc/apt/preferences.d/mozilla
    apt update
    apt install firefox thunderbird -y
}

setup_zram() {
    apt install zram-tools -y
    echo -e "ALGO=zstd\nPERCENT=20" | sudo tee -a /etc/default/zramswap
    systemctl restart zramswap
    swapon -s
}


ask_reboot() {
    echo 'Reboot now? (y/n)'
    while true; do
        read choice
        if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
            reboot
            exit 0
        fi
        if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
            break
        fi
    done
}

msg() {
    tput setaf 2
    echo "[*] $1"
    tput sgr0
}

error_msg() {
    tput setaf 1
    echo "[!] $1"
    tput sgr0
}

check_root_user() {
    if [ "$(id -u)" != 0 ]; then
        echo 'Please run the script as root!'
        echo 'We need to do administrative tasks'
        exit
    fi
}

show_menu() {
    echo 'Choose what to do: '
    echo '1 - Apply everything.'
    echo 'q - Exit'
    echo
}

main() {
    check_root_user
    while true; do
        show_menu
        read -p 'Enter your choice: ' choice
        case $choice in
        1)
            auto
            msg 'Done!'
            ask_reboot
            ;;
        q)
            exit 0
            ;;

        *)
            error_msg 'Wrong input!'
            ;;
        esac
    done

}

auto() {
    msg 'Updating system'
    update_system
    msg 'Removing snaps and snapd'
    remove_snaps
    msg 'Disabling ubuntu report'
    disable_ubuntu_report
    msg 'Removing annoying appcrash popup'
    remove_appcrash_popup
    msg 'Setting up flathub'
    setup_flathub
    msg 'Installing Firefox and Thunderbird from mozilla repository'
    restore_firefox
    msg 'Setting up zram'
    setup_zram
    msg 'Cleaning up'
    cleanup
}

(return 2> /dev/null) || main
