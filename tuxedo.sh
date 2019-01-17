#!/bin/bash
#
#  tuxedo.sh
#
#  Copyright (C) TUXEDO Computers GmbH <tux@tuxedocomputers.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

# Version: 3.43.2

cd $(dirname $0) || return 0
SCRIPTPATH=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPTPATH")

BASE_URL="https://raw.githubusercontent.com/tuxedocomputers/tuxedo.sh/master"

# additional packages that should be installed
PACKAGES="cheese pavucontrol brasero gparted pidgin vim obexftp ethtool xautomation curl linssid unrar"
PACKAGES_UBUNTU="xbacklight exfat-fuse exfat-utils gstreamer1.0-libav libgtkglext1 mesa-utils gnome-tweaks"
PACKAGES_SUSE="exfat-utils fuse-exfat"

error=0
trap 'error=$(($? > $error ? $? : $error))' ERR
set errtrace
xset s off
xset -dpms

lsb_dist_id="$(lsb_release -si)"   # e.g. 'Ubuntu', 'LinuxMint', 'openSUSE project'
lsb_release="$(lsb_release -sr)"   # e.g. '13.04', '15', '12.3'
lsb_codename="$(lsb_release -sc)"  # e.g. 'raring', 'olivia', 'Dartmouth'

apt_opts='-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew --fix-missing'
zypper_opts='-n'

product="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/product_name" | tr ' ,/-' '_')" # e.g. 'U931'
board="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/board_name" | tr ' ,/-' '_')"

case $product in
    U931|U953|INFINITYBOOK13V2|InfinityBook13V3|InfinityBook15*|Skylake_Platform) 
        product="U931"
        grubakt="NOGRUB"
        ;;
    P65_67RS*|P65_67RP*|P65xRP|P67xRP|P65xH*|P65_P67H*)
        grubakt="02GRUB"
        ;;
    P7xxDM*)
        grubakt="NOGRUB"
        ;;
    P7xxTM*)
        grubakt="03GRUB"
        ;;
    P775DM3*)
        grubakt="01GRUB"
        ;;
    *) : ;;
esac

case $board in
    P95*) fix="audiofix";;
    *) : ;;
esac

if [ "$EUID" -ne 0 ]; then
    echo "You aren't 'root', but '$(whoami)'. Aren't you?!"
    exec sudo su -c "/bin/bash '$(basename $0)'"
fi

exec 3>&1 &>tuxedo.log

if hash xterm 2>/dev/null; then
    exec xterm -geometry 150x50 -e tail -f tuxedo.log &
fi

echo "$(basename $0)"
lsb_release -a

case "$lsb_dist_id" in
    Ubuntu)
        install_cmd="apt-get $apt_opts install"
        upgrade_cmd="apt-get $apt_opts dist-upgrade"
        refresh_cmd="apt-get $apt_opts update"
        clean_cmd="apt-get -y clean"
        ;;
    openSUSE*|SUSE*)
        install_cmd="zypper $zypper_opts install -l"
        upgrade_cmd="zypper $zypper_opts update -l"
        refresh_cmd="zypper $zypper_opts refresh"
        clean_cmd="zypper $zypper_opts clean --all"
        ;;
    *)
        echo "Unknown Distribution: '$lsb_dist_id'"
        ;;
esac

has_nvidia_gpu() {
    lspci -nd 10de: | grep -q '030[02]:'
}

has_skylake_cpu() {
    lspci -nd 8086: | grep -q '19[01][048cf]'
}

has_kabylake_cpu() {
    [ "$(cat /proc/cpuinfo | grep -i "model name" | awk -F"-" '{print $2}' | head -1 | cut -c1)" = "7" ]
}

has_fingerprint_reader() {
    [ -x "$(which lsusb)" ] || $install_cmd usbutils
    lsusb -d 0483: || lsusb -d 147e: || lsusb -d 12d1: || lsusb -d 1c7a:0603
}

has_threeg() {
    [ -x "$(which lsusb)" ] || $install_cmd usbutils
    lsusb -d 12d1:15bb
}

add_apt_repository() {
    add-apt-repository -y $1
}

pkg_is_installed() {
    case "$lsb_dist_id" in
        Ubuntu)
            [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
            ;;
        openSUSE*|SUSE*)
            rpm -q "$1" >/dev/null
            ;;
    esac
}

task_grub() {
    local default_grub=/etc/default/grub

    case "$lsb_dist_id" in
        Ubuntu)
            case "$grubakt" in
                01GRUB)
                    grub_options=("acpi_osi=Linux" "acpi_backlight=vendor")
                    ;;
                02GRUB)
                    grub_options=("acpi_os_name=Linux" "acpi_osi=" "acpi_backlight=vendor" "i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                03GRUB)
                    grub_options=("acpi_osi=" "acpi_os_name=Linux")
                    ;;
                *)
                    grub_options=("acpi_osi=" "acpi_os_name=Linux" "acpi_backlight=vendor")
                    ;;
            esac

            for option in ${grub_options[*]}; do
                if ! grep -q $option "$default_grub"; then
                    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"\(.*\)"/"\1 '"$option"'"/' $default_grub
                fi
            done

            if has_nvidia_gpu; then
                sed -i '/^GRUB_CMDLINE_LINUX=/ s/nomodeset//' $default_grub
            fi

            sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT.*/,1 aGRUB_GFXPAYLOAD_LINUX=1920*1080' $default_grub
            update-grub
            ;;

        openSUSE*|SUSE*)
            case "$grubakt" in
                01GRUB)
                    grub_options=("loglevel=0" "acpi_osi=Linux" "acpi_backlight=vendor")
                    ;;
                02GRUB)
                    grub_options=("loglevel=0" "acpi_os_name=Linux" "acpi_osi=" "acpi_backlight=vendor" "i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                03GRUB)
                    grub_options=("loglevel=0" "acpi_osi=" "acpi_os_name=Linux")
                    ;;
                *)
                    grub_options=("loglevel=0" "acpi_osi=" "acpi_os_name=Linux" "acpi_backlight=vendor")
                    ;;
            esac

            for option in ${grub_options[*]}; do
                if ! grep -q $option "$default_grub"; then
                    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"\(.*\)"/"\1 '"$option"'"/' $default_grub
                fi
            done

            grub2-mkconfig -o /boot/grub2/grub.cfg
            ;;
    esac
}

task_grub_test() {
    return 0
}

task_nvidia() {
    case "$lsb_dist_id" in
        Ubuntu)
            if [ "$lsb_release" == "16.04" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ "$lsb_release" == "16.10" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ "$lsb_release" == "17.04" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ "$lsb_release" == "18.04" ]; then
                $install_cmd nvidia-driver-390 mesa-utils nvidia-prime vdpau-va-driver python-appindicator python-cairo python-gtk2
            else
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            fi
            ;;
        openSUSE*|SUSE*)
            if [ "$DESKTOP_SESSION" == "gnome" ]; then
                $install_cmd lightdm
                update-alternatives --set default-displaymanager /usr/lib/X11/displaymanagers/lightdm
            fi

            if $(lspci -nd '10de:' | grep -q '030[02]:' && lspci -nd '8086:' | grep -q '0300:'); then
                $install_cmd nvidia-computeG04 nvidia-gfxG04-kmp-default nvidia-glG04 x11-video-nvidiaG04 suse-prime
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 afi' /etc/X11/xdm/Xsetup
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 a\.\/etc\/X11\/xinit\/xinitrc\.d\/prime-offload\.sh' /etc/X11/xdm/Xsetup
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 athen' /etc/X11/xdm/Xsetup
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 aif\ \[\ \-f\ /etc/X11/xinit/xinitrc\.d/prime-offload\.sh\ \]\;' /etc/X11/xdm/Xsetup
                sed -i -e 's/Intel/modesetting/' "/etc/prime/prime-offload.sh"
                sed -i -e 's/Driver\ \"intel\"/Driver\ \"modesetting\"/' "/etc/prime/xorg.conf"
                sed -i -e 's/Option\ \"UseDisplayDevice\"\ \"None\"/#Option\ \"UseDisplayDevice\"\ \"None\"/' "/etc/prime/xorg.conf"
            else
                $install_cmd dkms nvidia-computeG04 nvidia-gfxG04-kmp-default nvidia-glG04 x11-video-nvidiaG04
            fi
            ;;
    esac
}

task_nvidia_test() {
    case "$lsb_dist_id" in
        Ubuntu)
            pkg_is_installed nvidia-390 || pkg_is_installed nvidia-driver-390 || pkg_is_installed nvidia-381
            ;;
        openSUSE*|SUSE*)
            pkg_is_installed nvidia-computeG04
            ;;
    esac
}

task_fingerprint() {
    case "$lsb_dist_id" in
        Ubuntu)
            $install_cmd libfprint0 libpam-fprintd fprint-demo
            ;;
        openSUSE*|SUSE*)
            $install_cmd libfprint0 pam_fprint
            ;;
    esac
}

task_fingerprint_test() {
    case "$lsb_dist_id" in
        Ubuntu)          pkg_is_installed fprint-demo && pkg_is_installed libfprint0;;
        openSUSE*|SUSE*) pkg_is_installed libfprint0;;
    esac
}

task_wallpaper() {
    case "$lsb_dist_id" in
        Ubuntu)          $install_cmd tuxedo-wallpapers;;
        openSUSE*|SUSE*) $install_cmd tuxedo-one-wallpapers;;
    esac

    if pkg_is_installed ubuntu-desktop; then
        local filename="30_tuxedo-settings.gschema.override"
        download_file ${BASEDIR}/files/${filename} ${BASE_URL}/files/${filename} /usr/share/glib-2.0/schemas/${filename}
        glib-compile-schemas /usr/share/glib-2.0/schemas
    elif pkg_is_installed kubuntu-desktop; then
        local filename="80-tuxedo.js"
        download_file ${BASEDIR}/files/${filename} ${BASE_URL}/files/${filename} /usr/share/glib-2.0/schemas/${filename}
    elif pkg_is_installed xubuntu-desktop; then
        local filename="xfce4-desktop.xml"
        download_file ${BASEDIR}/files/${filename} ${BASE_URL}/files/${filename} /usr/share/glib-2.0/schemas/${filename}
    fi
}

task_wallpaper_test() {
    pkg_is_installed tuxedo-wallpapers || pkg_is_installed tuxedo-one-wallpapers
}

task_misc() {
    case "$lsb_dist_id" in
        Ubuntu)
            if ! [ -x "$(which gsettings)" ]; then
                echo "gsettings not found or not executable. Skipping misc!"
                return 1
            fi

            su $(logname) <<EOSU
            schema="com.canonical.Unity.Lenses"
            val="['more_suggestions-amazon.scope', 'more_suggestions-u1ms.scope', 'more_suggestions-populartracks.scope', 'music-musicstore.scope', 'more_suggestions-ebay.scope', 'more_suggestions-ubuntushop.scope', 'more_suggestions-skimlinks.scope']"

            if gsettings writable $schema disabled-scopes; then
                gsettings set $schema disabled-scopes "$val"
            fi

            if [ "$lsb_release" == "18.04" ] && gsettings writable org.gnome.desktop.peripherals.touchpad click-method; then
                gsettings set org.gnome.desktop.peripherals.touchpad click-method areas
            fi
EOSU
            ;;
    esac
}

task_misc_test() {
    return 0
}

download_file() {
    local sourceFilePath=$1
    local urlPath=$2
    local destination=$3

    local sourceFile=""

    if [ -f ${sourceFilePath} ] ; then
        sourceFile=file://${sourceFilePath}
    else
        sourceFile=${urlPath}
    fi

    curl -o- ${sourceFile} > ${destination}
}

task_repository() {
    local tmp
    tmp="$(mktemp -d)"

    case "$lsb_dist_id" in
        Ubuntu)
            local UBUNTU_KEYNAME="ubuntu.pub"
            local UBUNTU_KEYFILE_PATH=${tmp}/${UBUNTU_KEYNAME}
            local UBUNTU_REPO="tuxedo-computers.list"
            local UBUNTU_REPO_FILEPATH="/etc/apt/sources.list.d/tuxedo-computers.list"

            download_file ${BASEDIR}/keys/${UBUNTU_KEYNAME} ${BASE_URL}/keys/${UBUNTU_KEYNAME} ${UBUNTU_KEYFILE_PATH}
            download_file ${BASEDIR}/sourcelists/${UBUNTU_REPO} ${BASE_URL}/sourcelists/${UBUNTU_REPO} ${UBUNTU_REPO_FILEPATH}

            sed -e 's/\${lsb_codename}/'${lsb_codename}'/g' ${UBUNTU_REPO_FILEPATH} > ${UBUNTU_REPO_FILEPATH}.bak && mv ${UBUNTU_REPO_FILEPATH}.bak ${UBUNTU_REPO_FILEPATH}
            
            apt-key add ${UBUNTU_KEYFILE_PATH}
            ;;
        openSUSE*|SUSE*)
            local SUSE_KEYNAME="suse.pub"
            local NVIDIA_KEYNAME="nvidia.pub"
            local SUSE_ISV_REPO="repo-isv-tuxedo.repo"
            local SUSE_NVIDIA_REPO="repo-nvidia-tuxedo.repo"

            local SUSE_KEYFILE_PATH=${tmp}/${SUSE_KEYNAME}
            local NVIDIA_KEYFILE_PATH=${tmp}/${NVIDIA_KEYNAME}

            download_file ${BASEDIR}/keys/${SUSE_KEYNAME} ${BASE_URL}/keys/${SUSE_KEYNAME} ${SUSE_KEYFILE_PATH}
            download_file ${BASEDIR}/keys/${NVIDIA_KEYNAME} ${BASE_URL}/keys/${NVIDIA_KEYNAME} ${NVIDIA_KEYFILE_PATH}
      
            download_file ${BASEDIR}/sourcelists/${SUSE_ISV_REPO} ${BASE_URL}/sourcelists/${SUSE_ISV_REPO} "/etc/zypp/repos.d/repo-isv-tuxedo.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_NVIDIA_REPO} ${BASE_URL}/sourcelists/${SUSE_NVIDIA_REPO} "/etc/zypp/repos.d/repo-nvidia-tuxedo.repo"

            rpmkeys --import ${SUSE_KEYFILE_PATH}
            rpmkeys --import ${NVIDIA_KEYFILE_PATH}
            ;;
    esac

    rm -rf "$tmp"
}

task_repository_test() {
    case "$lsb_dist_id" in
        Ubuntu)
            apt-key list|grep -q TUXEDO || return 1
            ;;
        openSUSE*|SUSE*)
            [ -s /etc/zypp/repos.d/repo-isv-tuxedo.repo ]    || return 1
            [ -s /etc/zypp/repos.d/repo-nvidia-tuxedo.repo ] || return 1
            ;;
    esac

    echo "repository keys successfully installed!"
    return 0
}

task_update() {
    $refresh_cmd
    $upgrade_cmd
}

task_update_test() {
    return 0
}

task_install_kernel() {
    $refresh_cmd
    $upgrade_cmd
    case "$lsb_dist_id" in
        Ubuntu)
            case "$lsb_codename" in
                xenial)  $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                yakkety) $install_cmd linux-image-4.11.8-041108-generic linux-headers-4.11.8-041108-generic linux-headers-4.11.8-041108;;
                zesty)   $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                artful)  $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                bionic)  $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                *)       $install_cmd linux-generic ;;
            esac
            ;;
        openSUSE*|SUSE*)
            case "$lsb_release" in
                42.1) $install_cmd -f kernel-default-4.4.0-8.1.x86_64 kernel-default-devel-4.4.0-8.1.x86_64 kernel-firmware;;
                *)    : ;;
            esac
            ;;
    esac
}

task_install_kernel_test() {
    case "$lsb_dist_id" in
        Ubuntu)
            case "$lsb_codename" in
                xenial)  pkg_is_installed linux-generic;;
                yakkety) pkg_is_installed linux-image-4.11.8-041108-generic;;
                zesty)   pkg_is_installed linux-image-generic;;
                artful)  pkg_is_installed linux-image-generic;;
                bionic)  pkg_is_installed linux-image-generic;;
                *)       pkg_is_installed linux-generic || return 1 ;;
            esac
            ;;
        openSUSE*|SUSE*)
            pkg_is_installed kernel-default || return 1
            ;;
    esac

    return 0
}

task_firmware() {
    case "$lsb_dist_id" in
        Ubuntu)
            if [ $lsb_release == "16.04" ]; then
                wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-3160-17.ucode
            fi

            if [ $lsb_release == "18.04" ]; then
                if [ $fix == "audiofix" ]; then
                    $install_cmd oem-audio-hda-daily-dkms
                fi
            fi

            if has_threeg; then
            echo "options usbserial vendor=0x12d1 product=0x15bb" > "/etc/modprobe.d/huawai-me936.conf"
            echo 'ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="12d1", ATTR{idProduct}=="15bb", ATTR{bNumConfigurations}=="3", ATTR{bConfigurationValue}!="3" ATTR{bConfigurationValue}="3"' > "/lib/udev/rules.d/77-mm-huawei-configuration.rules"
	    fi

            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7260-17.ucode
            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7265-17.ucode
            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7265D-21.ucode
            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-19.ucode
            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-20.ucode
            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-21.ucode
            wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-22.ucode
            cp iwlwifi*.ucode /lib/firmware/
            rm -rf iwlwifi-*

            wget https://www.tuxedocomputers.com/support/i915/kbl_dmc_ver1_01.bin
            wget https://www.tuxedocomputers.com/support/i915/skl_dmc_ver1_26.bin
            wget https://www.tuxedocomputers.com/support/i915/skl_guc_ver6_1.bin
            [ -d /lib/firmware/i915 ] || mkdir /lib/firmware/i915
            cp kbl*.bin /lib/firmware/i915/
            cp skl*.bin /lib/firmware/i915

            ln -sf /lib/firmware/i915/kbl_dmc_ver1_01.bin /lib/firmware/i915/kbl_dmc_ver1.bin
            ln -sf /lib/firmware/i915/skl_dmc_ver1_26.bin /lib/firmware/i915/skl_dmc_ver1.bin
            ln -sf /lib/firmware/i915/skl_guc_ver6_1.bin /lib/firmware/i915/skl_guc_ver6.bin
            rm -rf kbl*.bin
            rm -rf skl*.bin
            ;;
        openSUSE*|SUSE*)
            if [ $product == "P65_P67RGRERA" ]; then
                $install_cmd r8168-dkms-8.040.00-10.57.noarch
                echo "blacklist r8169" > "/etc/modprobe.d/99-local.conf"
            fi
            ;;
    esac
}

task_firmware_test() {
    return 0
}

task_software() {
    case "$lsb_dist_id" in
        Ubuntu)
            $install_cmd laptop-mode-tools
            [ -d /etc/laptop-mode/conf.d ] || mkdir -p /etc/laptop-mode/conf.d
            echo "CONTROL_ETHERNET=0" > /etc/laptop-mode/conf.d/ethernet.conf

            if [ "$lsb_release" == "15.10" ]; then
                sed -i "s#\(^AUTOSUSPEND_RUNTIME_DEVTYPE_BLACKLIST=\).*#\1usbhid#" /etc/laptop-mode/conf.d/runtime-pm.conf
            fi

            if [ -e "/sys/class/backlight/intel_backlight/max_brightness" ]; then
                cat /sys/class/backlight/intel_backlight/max_brightness > /sys/class/backlight/intel_backlight/brightness
            fi

            if [ -n "$PACKAGES_UBUNTU" ]; then
                $install_cmd $PACKAGES_UBUNTU
            fi

            apt-get -y remove unity-webapps-common app-install-data-partner apport ureadahead

            if pkg_is_installed ubuntu-desktop; then
                $install_cmd classicmenu-indicator
            fi
            ;;
        openSUSE*|SUSE*)
            if [ -n "$PACKAGES_SUSE" ]; then
                $install_cmd $PACKAGES_SUSE
            fi
            ;;
    esac

    if [ -n "$PACKAGES" ]; then
        $install_cmd $PACKAGES
    fi
}

task_software_test() {
    case "$lsb_dist_id" in
        Ubuntu|LinuxMint|elementary*)
            pkg_is_installed laptop-mode-tools || return 1
            ;;
    esac

    for p in $PACKAGES; do
        pkg_is_installed "$p" || return 1
    done

    return 0
}

task_clean() {
    $clean_cmd
    find /var/lib/apt/lists -type f -exec rm -fv {} \; 2>/dev/null
}

task_clean_test() {
    return 0
}

task_init() {
    [ -x "$(which curl)" ] || $install_cmd curl
}

task_init_test() {
    [ -x "$(which curl)" ]
}

do_task() {
    error=0
    printf "%-16s " "$1" >&3
    echo "Calling task $1"
    task_$1

    if [ $error -eq 0 ] && task_${1}_test; then
        echo -e "\e[1;32mOK\e[0m" >&3
        echo "Task $1 OK"
    else
        echo -e "\e[1;31mFAILED\e[0m" >&3
        echo "Task $1 FAILED"
    fi
}

do_task clean
do_task update
do_task init
do_task repository
do_task install_kernel
do_task grub
has_fingerprint_reader && do_task fingerprint
has_nvidia_gpu && do_task nvidia
do_task wallpaper
do_task firmware
do_task software
do_task misc
do_task clean
do_task update

read -p "Press <ENTER> to reboot" >&3 2>&1
exec reboot
