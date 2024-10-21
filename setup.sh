#!/bin/bash

# Check if the script is executable
if [[ ! -x "$0" ]]; then
    echo "This script is not executable. You can make it executable with the following command:"
    echo "chmod +x $0"
    echo "After that, run the script again."
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root! Exiting..."
    exit 1
fi

clear

# Welcome message
echo "Welcome to the Fedora Setup Script!"
echo
echo "Please ensure your system is updated before proceeding."

read -p "Would you like to proceed? (y/n): " proceed

if [ "$proceed" != "y" ]; then
    echo "Installation aborted."
    exit 1
fi

# Step 1: Overwrite /etc/dnf/dnf.conf
echo "Updating dnf configuration for faster updates..."
cat <<EOF > /etc/dnf/dnf.conf
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
fastestmirror=true
max_parallel_downloads=10
deltarpm=true
EOF

# Step 2: Create directory and overwrite /etc/systemd/resolved.conf.d/99-dns-over-tls.conf
echo "Setting up custom DNS servers for better privacy..."
mkdir -p /etc/systemd/resolved.conf.d
cat <<EOF > /etc/systemd/resolved.conf.d/99-dns-over-tls.conf
[Resolve]
DNS=1.1.1.2#security.cloudflare-dns.com 1.0.0.2#security.cloudflare-dns.com 2606:4700:4700::1112#security.cloudflare-dns.com 2606:4700:4700::1002#security.cloudflare-dns.com
DNSOverTLS=yes
EOF

# Step 3: Run the specified DNF commands
echo "Enabling RPM Fusion free and non-free..."
dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
echo "Installing Media Codecs to get proper multimedia playback..."
dnf groupupdate 'core' 'multimedia' 'sound-and-video' --setopt='install_weak_deps=False' --exclude='PackageKit-gstreamer-plugin' --allowerasing && sync
dnf swap -y 'ffmpeg-free' 'ffmpeg' --allowerasing
dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel ffmpeg gstreamer-ffmpeg
dnf install -y lame\* --exclude=lame-devel
dnf group upgrade --with-optional Multimedia
echo "Installing H/W Video Acceleration"
dnf install -y ffmpeg ffmpeg-libs libva libva-utils

# Step 4: Ask user for chipset type
echo "Please select your chipset type:"
echo "1) Recent Intel chipset (5th Gen and above)"
echo "2) AMD"
read -p "Enter the number (1 or 2): " chipset

case "$chipset" in
    1)
        echo "Intel chipset selected. Installing Intel media driver..."
        dnf swap -y libva-intel-media-driver intel-media-driver --allowerasing
        ;;
    2)
        echo "AMD chipset selected. Installing AMD media driver..."
        dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
        ;;
    *)
        echo "Invalid input. No media driver changes made."
        ;;
esac
echo "Installing OpenH264 for Firefox..."
dnf config-manager --set-enabled fedora-cisco-openh264
dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264
echo "Disabling Gnome Software from Startup Apps..."
rm -f /etc/xdg/autostart/org.gnome.Software.desktop
echo "Updating..."
sudo dnf -y update
sudo dnf -y upgrade --refresh

# Important note
echo -e "\n\033[38;5;202m\033[1mImportant: After this, enable the OpenH264 Plugin in Firefox's settings.\033[0m"

# Completion message
echo "Setup complete! All specified actions have been performed."

# Prompt for reboot
echo "A reboot is highly recommended to apply all changes."
read -rp "Would you like to reboot now? (y/n): " HYP

if [[ "$HYP" =~ ^[Yy]$ ]]; then
    echo "Rebooting the system..."
    systemctl reboot
fi
