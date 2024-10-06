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

install_basic_packages() {
    apt install vim net-tools rsync openssh-server -y
    apt install --install-suggests gnome-software -y
}

install_extra_packages() {
    apt install ntp flatpak vim net-tools vim build-essential ffmpeg  rar unrar  \
	 	p7zip-rar libavcodec-extra gstreamer1.0-*  gstreamer1.0-plugins* gnome-shell-extension-appindicator tigervnc-viewer dnsutils \
	 	meld astyle podman inxi vlc texlive-extra-utils graphicsmagick-imagemagick-compat  python3-pip pipx    \
		apt-transport-https ca-certificates curl software-properties-common wget fonts-liberation libu2f-udev libvulkan1 \
		freeplane git xsel gnome-tweaks gnome-shell-extension-prefs gnome-shell-extensions hplip keepassxc distrobox -y
}

setup_fonts() {
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections    
    apt install ttf-mscorefonts-installer -y
}

setup_flathub() {
    apt install flatpak -y
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install com.github.tchx84.Flatseal -y
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

setup_tlp() {
    apt install tlp tlp-rdw smartmontools -y
    apt remove power-profiles-daemon -y
	echo '
TLP_ENABLE=1
CPU_SCALING_GOVERNOR_ON_BAT=powersave
RESTORE_THRESHOLDS_ON_BAT=1
USB_AUTOSUSPEND=0
USB_EXCLUDE_AUDIO=1
USB_EXCLUDE_PHONE=1
USB_EXCLUDE_BTUSB=1
' > /etc/tlp.conf 
    systemctl enable tlp.service
    systemctl start tlp.service
    systemctl mask systemd-rfkill.service systemd-rfkill.socket
    tlp-stat -s
}

install_chrome() {
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt install ./google-chrome-stable_current_amd64.deb -y
    rm -f google-chrome-stable_current_amd64.deb
}

install_veracrypt() {
    export VC_VERSION="1.26.14"
    wget https://launchpad.net/veracrypt/trunk/$VC_VERSION/+download/veracrypt-$VC_VERSION-Ubuntu-24.04-amd64.deb
    wget https://launchpad.net/veracrypt/trunk/$VC_VERSION/+download/veracrypt-$VC_VERSION-Ubuntu-24.04-amd64.deb.sig
    wget https://www.idrix.fr/VeraCrypt/VeraCrypt_PGP_public_key.asc
    gpg --import VeraCrypt_PGP_public_key.asc
    gpg --verify veracrypt-$VC_VERSION-Ubuntu-24.04-amd64.deb.sig
    apt install ./veracrypt-$VC_VERSION-Ubuntu-24.04-amd64.deb -y
    rm -f veracrypt-$VC_VERSION-Ubuntu-24.04-amd64.deb
    rm -f veracrypt-$VC_VERSION-Ubuntu-24.04-amd64.deb.sig
    rm -f VeraCrypt_PGP_public_key.asc
    rm -f VeraCrypt_PGP_public_key.asc.1   
}

install_vscode() {
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    apt update -y
    apt install code -y
}

install_codium() {
    flatpak install app/com.vscodium.codium/x86_64/stable -y
}

install_qemu() {
    systemctl stop pcscd.socket
    systemctl stop pcscd
    systemctl disable pcscd
    systemctl mask pcscd
    apt install qemu-system qemu-kvm libvirt-daemon libvirt-clients bridge-utils virt-manager libvirt-daemon-system \
        virtinst qemu-utils virt-viewer spice-client-gtk gir1.2-spice* ebtables swtpm swtpm-tools ovmf virtiofsd -y
	virsh net-autostart default
    modprobe vhost_net    
}

setup_firewall() {
    apt install ufw gufw -y
    systemctl stop ssh.socket ssh
    systemctl disable ssh
    ufw enable    
    ufw default deny incoming
    ufw default allow outgoing
    ufw status verbose
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
    msg 'Disabling ubuntu report'
    disable_ubuntu_report
    msg 'Removing annoying appcrash popup'
    remove_appcrash_popup    
    msg 'Updating system'
    update_system
    msg 'Removing snaps and snapd'
    remove_snaps
    msg 'Setting up zram'
    setup_zram    
    msg 'Installing basic packages'
    install_basic_packages
    msg 'Setting up flathub'
    setup_flathub    
    msg 'Setting up TLP'
    setup_tlp
    msg 'Setting up firewall'
    setup_firewall
    msg 'Installing Firefox and Thunderbird from mozilla repository'
    restore_firefox
    msg 'Installing extra packages'
    install_extra_packages
    msg 'Install MS fonts'
    setup_fonts
    msg 'Install chrome'
    install_chrome
    msg 'Install veracrypt'
    install_veracrypt
    msg 'Install code'
    install_vscode
    msg 'Install codium'
    install_codium
    msg 'Install qemu'
    install_qemu
    msg 'Cleaning up'
    cleanup
}

(return 2> /dev/null) || main
