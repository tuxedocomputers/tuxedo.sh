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

# Version: 3.43.4
# Date:	2020-10-06

cd $(dirname $0) || return 0
SCRIPTPATH=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPTPATH")

BASE_URL="https://raw.githubusercontent.com/tuxedocomputers/tuxedo.sh/master"

if [ "$EUID" -ne 0 ]; then
    echo "tuxedo.sh muss mit root Rechten ausgeführt werden! / tuxedo.sh must be executed with root privileges!"
    exec sudo su -c "/bin/bash '$(basename $0)'"
fi

if [ -f /var/log/tuxedo-install.log ]; then
    echo "Sie besitzen eine TUXEDO WebFAI Installation. Es gibt nichts zu tun. / You have a TUXEDO WebFAI installation. There is nothing to do."
    exit 0
fi

# additional packages that should be installed
PACKAGES="cheese pavucontrol brasero gparted pidgin vim obexftp ethtool xautomation curl linssid unrar xbindkeys"

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

vendor="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/board_vendor" | tr ' ,/-' '_')"
product="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/product_name" | tr ' ,/-' '_')" # e.g. 'U931'
board="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/board_name" | tr ' ,/-' '_')"

case $vendor in
	TUXEDO) echo "nix" >/dev/null;;
	TUXEDO*) echo "nix" >/dev/null;;
	Type2___Board_Vendor_Name1) lspci -nd '8086:' | grep -q '8086:24f3' && echo "It seems you do not use a TUXEDO device. If this is a mistake, please contact us" && exit 0;;
	*) echo "It seems you do not use a TUXEDO device. If this is a mistake, please contact us" && exit 0;;
esac

case $product in
    U931|U953|INFINITYBOOK13V2|InfinityBook13V3|InfinityBook14v1|InfinityBook15*|Skylake_Platform) 
        product="U931"
        grubakt="NOGRUB"
        ;;
    P65_67RS*|P65_67RP*|P65xRP|P67xRP|P65xH*|P65_P67H*|NHxxRZQ*)
        grubakt="02GRUB"
        ;;
    P7xxDM*)
        grubakt="NOGRUB"
        ;;
    P7xxTM*)
        grubakt="NOGRUB"
        ;;
    P775DM3*)
        grubakt="NOGRUB"
        ;;
    P95_H*)
        grubakt="NOGRUB"
        ;;
    X35R*)
        grubakt="03GRUB"
        ;;

    PF5PU1G*)
        grubakt="04GRUB"
        ;;
    PB50_70DFx_DDx*)
        grubakt="05GRUB"
        ;;
    *) : ;;
esac

case $board in
    P95*) fix="audiofix";;
    P9*) fix="fanfix";;
    *) : ;;
esac

case $board in
    P95_96_97Ex_Rx) fix="tuxaudfix";;
    P9XXRC) fix="tuxaudfix";;
    *) : ;;
esac

case $board in
    N350TW) fix="tuxrestfix";;
    *) : ;;
esac

case $board in
    NHxxRZQ) fix="micfix";;
    NHxxRZ) fix="micfix";;
    L140CU) fix="micfix";;
    NL40_50GU) fix="micfix";;
    NH5xAx) fix="micfix";;
    NJ50_NJ70CU) fix="micfix";;
    PB50_70D*) fix="micfix";;
    AURA1501) fix="micfix";;
    *) : ;;
esac

case $board in
    POLARIS1501A1650TI) fix="amdgpu";;
    POLARIS1501A2060) fix="amdgpu";;
    POLARIS1701A1650TI) fix="amdgpu";;
    POLARIS1701A2060) fix="amdgpu";;
    PULSE1401) fix="amdgpu";;
    PULSE1501) fix="amdgpu";;
    *) : ;;
esac

case $board in
    X170SM) fix="tuxkeyite";;
    *) : ;;
esac

case $board in
    P95_96_97Ex_Rx|PB50_70EF_ED_EC|PB50_70RF_RD_RC|P9XXRC)
        grubakt="NOGRUB"
        tpfix="TPFIX"
        airfix="AIRFIX"
        nvsusfix="NVSUSFIX"
        audsusfix="AUDSUSFIX"
	;;
    *) : ;;
esac

exec 3>&1 &>tuxedo.log

if hash xterm 2>/dev/null; then
    exec xterm -geometry 150x50 -e tail -f tuxedo.log &
elif hash gnome-terminal 2>/dev/null; then
    exec gnome-terminal -- tail -f tuxedo.log &
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
                02GRUB)
                    grub_options=("i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                NOGRUB)
                    grub_options=""
                    ;;
		03GRUB)
		    grub_options="psmouse.elantech_smbus=0"
		    ;;
                04GRUB)
		    grub_options="iommu=soft"
		    ;;
                05GRUB)
                    grub_options="i8042.nopnp"
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
                02GRUB)
                    grub_options=("loglevel=0" "i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                *)
                    grub_options=("loglevel=0")
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
		$install_cmd nvidia-driver-440 mesa-utils nvidia-prime python-appindicator python-cairo python-gtk2
	    elif [ "$lsb_release" == "20.04" ]; then
		$install_cmd nvidia-driver-440 mesa-utils nvidia-prime
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
		$install_cmd nvidia-computeG05 nvidia-gfxG05-kmp-default nvidia-glG05 x11-video-nvidiaG05 xf86-video-intel dkms-bbswitch
            else
		$install_cmd dkms nvidia-computeG05 nvidia-gfxG05-kmp-default nvidia-glG05 x11-video-nvidiaG05
            fi
            ;;
    esac
}

task_nvidia_test() {
    case "$lsb_dist_id" in
        Ubuntu)
            pkg_is_installed nvidia-390 || pkg_is_installed nvidia-driver-390 || pkg_is_installed nvidia-driver-440
            ;;
        openSUSE*|SUSE*)
            pkg_is_installed nvidia-computeG05
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
    #i915
    echo "options i915 enable_dpcd_backlight=1" >> /etc/modprobe.d/tuxedo-i915.conf
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

    if ! [ -x "$(command -v curl)" ]; then
        $install_cmd curl
    fi

    case "$lsb_dist_id" in
        Ubuntu)
            local UBUNTU_KEYNAME="ubuntu.pub"
            local UBUNTU_KEYFILE_PATH=${tmp}/${UBUNTU_KEYNAME}
            local UBUNTU_REPO="tuxedo-computers.list"
	    local UBUNTU_MIRROR="tuxedo-deb-mirrors.list"
	    local UBUNTU_REPO_FILEPATH="/etc/apt/sources.list.d/tuxedo-computers.list"
            local UBUNTU_MIRROR_FILEPATH="/etc/apt/tuxedo-deb-mirrors.list"

            download_file ${BASEDIR}/keys/${UBUNTU_KEYNAME} ${BASE_URL}/keys/${UBUNTU_KEYNAME} ${UBUNTU_KEYFILE_PATH}
            download_file ${BASEDIR}/sourcelists/${UBUNTU_REPO} ${BASE_URL}/sourcelists/${UBUNTU_REPO} ${UBUNTU_REPO_FILEPATH}
            download_file ${BASEDIR}/sourcelists/${UBUNTU_MIRROR} ${BASE_URL}/sourcelists/${UBUNTU_MIRROR} ${UBUNTU_MIRROR_FILEPATH}
            sed -e 's/\${lsb_codename}/'${lsb_codename}'/g' ${UBUNTU_REPO_FILEPATH} > ${UBUNTU_REPO_FILEPATH}.bak && mv ${UBUNTU_REPO_FILEPATH}.bak ${UBUNTU_REPO_FILEPATH}
            sed -e 's/\${lsb_codename}/'${lsb_codename}'/g' ${UBUNTU_MIRROR_FILEPATH} > ${UBUNTU_MIRROR_FILEPATH}.bak && mv ${UBUNTU_MIRROR_FILEPATH}.bak /etc/apt/sources.list
            
            apt-key add ${UBUNTU_KEYFILE_PATH}
            ;;
        openSUSE*|SUSE*)
            local SUSE_KEYNAME="suse.pub"
            local GRAPHICS_KEYNAME="graphics.pub"
            local RPM_KEYNAME="rpm.pub"
            local KERNEL_KEYNAME="kernel.pub"

            local SUSE_ISV_REPO="repo-isv-tuxedo.repo"
            local SUSE_GRAPHICS_REPO="repo-graphics-tuxedo.repo"
            local SUSE_RPM_REPO="repo-rpm-tuxedo.repo"
            local SUSE_KERNEL_REPO="repo-kernel-tuxedo.repo"
            local SUSE_MIRROR_NONOSS_REPO="repo-non-oss.repo"
            local SUSE_MIRROR_OSS_REPO="repo-oss.repo"
            local SUSE_MIRROR_UP_NONOSS_REPO="repo-update-non-oss.repo"
            local SUSE_MIRROR_UP_OSS_REPO="repo-update-oss.repo"

            local SUSE_KEYFILE_PATH=${tmp}/${SUSE_KEYNAME}
            local GRAPHICS_KEYFILE_PATH=${tmp}/${GRAPHICS_KEYNAME}
            local RPM_KEYFILE_PATH=${tmp}/${RPM_KEYNAME}
            local KERNEL_KEYFILE_PATH=${tmp}/${KERNEL_KEYNAME}

	    rm -f /etc/zypp/repos.d/*
            download_file ${BASEDIR}/keys/${SUSE_KEYNAME} ${BASE_URL}/keys/${SUSE_KEYNAME} ${SUSE_KEYFILE_PATH}
            download_file ${BASEDIR}/keys/${GRAPHICS_KEYNAME} ${BASE_URL}/keys/${GRAPHICS_KEYNAME} ${GRAPHICS_KEYFILE_PATH}
            download_file ${BASEDIR}/keys/${RPM_KEYNAME} ${BASE_URL}/keys/${RPM_KEYNAME} ${RPM_KEYFILE_PATH}
            download_file ${BASEDIR}/keys/${KERNEL_KEYNAME} ${BASE_URL}/keys/${KERNEL_KEYNAME} ${KERNEL_KEYFILE_PATH}
      
            download_file ${BASEDIR}/sourcelists/${SUSE_ISV_REPO} ${BASE_URL}/sourcelists/${SUSE_ISV_REPO} "/etc/zypp/repos.d/repo-isv-tuxedo.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_GRAPHICS_REPO} ${BASE_URL}/sourcelists/${SUSE_GRAPHICS_REPO} "/etc/zypp/repos.d/repo-graphics-tuxedo.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_RPM_REPO} ${BASE_URL}/sourcelists/${SUSE_RPM_REPO} "/etc/zypp/repos.d/repo-rpm-tuxedo.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_KERNEL_REPO} ${BASE_URL}/sourcelists/${SUSE_KERNEL_REPO} "/etc/zypp/repos.d/repo-kernel-tuxedo.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_MIRROR_NONOSS_REPO} ${BASE_URL}/sourcelists/${SUSE_MIRROR_NONOSS_REPO} "/etc/zypp/repos.d/repo-non-oss.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_MIRROR_OSS_REPO} ${BASE_URL}/sourcelists/${SUSE_MIRROR_OSS_REPO} "/etc/zypp/repos.d/repo-oss.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_MIRROR_UP_NONOSS_REPO} ${BASE_URL}/sourcelists/${SUSE_MIRROR_UP_NONOSS_REPO} "/etc/zypp/repos.d/repo-update-non-oss.repo"
            download_file ${BASEDIR}/sourcelists/${SUSE_MIRROR_UP_OSS_REPO} ${BASE_URL}/sourcelists/${SUSE_MIRROR_UP_OSS_REPO} "/etc/zypp/repos.d/repo-update-oss.repo"

            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_ISV_REPO} > /etc/zypp/repos.d/${SUSE_ISV_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_ISV_REPO}.bak /etc/zypp/repos.d/${SUSE_ISV_REPO}
            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_RPM_REPO} > /etc/zypp/repos.d/${SUSE_RPM_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_RPM_REPO}.bak /etc/zypp/repos.d/${SUSE_RPM_REPO}
            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_KERNEL_REPO} > /etc/zypp/repos.d/${SUSE_KERNEL_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_KERNEL_REPO}.bak /etc/zypp/repos.d/${SUSE_KERNEL_REPO}
	    sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_GRAPHICS_REPO} > /etc/zypp/repos.d/${SUSE_GRAPHICS_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_GRAPHICS_REPO}.bak /etc/zypp/repos.d/${SUSE_GRAPHICS_REPO}
            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_MIRROR_NONOSS_REPO} > /etc/zypp/repos.d/${SUSE_MIRROR_NONOSS_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_MIRROR_NONOSS_REPO}.bak /etc/zypp/repos.d/${SUSE_MIRROR_NONOSS_REPO}
            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_MIRROR_OSS_REPO} > /etc/zypp/repos.d/${SUSE_MIRROR_OSS_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_MIRROR_OSS_REPO}.bak /etc/zypp/repos.d/${SUSE_MIRROR_OSS_REPO}
            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_MIRROR_UP_NONOSS_REPO} > /etc/zypp/repos.d/${SUSE_MIRROR_UP_NONOSS_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_MIRROR_UP_NONOSS_REPO}.bak /etc/zypp/repos.d/${SUSE_MIRROR_UP_NONOSS_REPO}
            sed -e 's/\${lsb_release}/'${lsb_release}'/g' /etc/zypp/repos.d/${SUSE_MIRROR_UP_OSS_REPO} > /etc/zypp/repos.d/${SUSE_MIRROR_UP_OSS_REPO}.bak && mv /etc/zypp/repos.d/${SUSE_MIRROR_UP_OSS_REPO}.bak /etc/zypp/repos.d/${SUSE_MIRROR_UP_OSS_REPO}

	    rpmkeys --import ${SUSE_KEYFILE_PATH}
            rpmkeys --import ${GRAPHICS_KEYFILE_PATH}
            rpmkeys --import ${RPM_KEYFILE_PATH}
            rpmkeys --import ${KERNEL_KEYFILE_PATH}
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
            [ -s /etc/zypp/repos.d/repo-graphics-tuxedo.repo ] || return 1
            [ -s /etc/zypp/repos.d/repo-rpm-tuxedo.repo ] || return 1
            [ -s /etc/zypp/repos.d/repo-kernel-tuxedo.repo ] || return 1
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
                bionic)  $install_cmd linux-generic-hwe-18.04 linux-image-generic-hwe-18.04 linux-headers-generic-hwe-18.04 linux-signed-generic-hwe-18.04;;
		focal)   $install_cmd linux-oem-20.04 linux-firmware intel-microcode;;
		*)       $install_cmd linux-generic;;
            esac
            ;;
        openSUSE*|SUSE*)
            case "$lsb_release" in
                42.1) $install_cmd -f kernel-default-4.4.0-8.1.x86_64 kernel-default-devel-4.4.0-8.1.x86_64 kernel-firmware;;
                15.1) $install_cmd -f -r repo-kernel-tuxedo -f kernel-default kernel-devel kernel-firmware;;
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
                bionic)  pkg_is_installed linux-image-generic-hwe-18.04;;
                focal)   pkg_is_installed linux-oem-20.04;;
		*)       pkg_is_installed linux-generic || return 1 ;;
            esac
            ;;
        openSUSE*|SUSE*)
            pkg_is_installed kernel-default || return 1
            ;;
    esac

    return 0
}

task_software() {
    case "$lsb_dist_id" in
        Ubuntu)
            $install_cmd gcc tlp xbacklight exfat-fuse exfat-utils gstreamer1.0-libav libgtkglext1 mesa-utils

            if [ $lsb_release == "16.04" ]; then
                wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-3160-17.ucode
                apt-get -y remove unity-webapps-common app-install-data-partner apport ureadahead
            fi

            if [ $lsb_release == "18.04" ]; then
                apt-get -y remove --purge ubuntu-web-launchers apport ureadahead app-install-data-partner kwalletmanager
                $install_cmd tuxedo-keyboard tuxedo-cc-wmi tuxedo-control-center tuxedo-tomte 
                if [ $fix == "audiofix" ]; then
                    $install_cmd oem-audio-hda-daily-dkms
                fi
		
		if [ $fix == "tuxaudfix" ]; then
                    $install_cmd tuxedo-audio-fix
                fi

                if [ $fix == "tuxrestfix" ]; then
                    $install_cmd tuxedo-restore-audio-fix
                fi

		if [ $fix == "micfix" ]; then
                    $install_cmd tuxedo-micfix1
                fi

		if [ $fix == "tuxkeyite" ]; then
                    $install_cmd tuxedo-keyboard-ite
                fi
            fi
	    if [ $lsb_release == "20.04" ]; then
                apt-get -y remove --purge apport 
                $install_cmd tuxedo-keyboard tuxedo-cc-wmi tuxedo-control-center tuxedo-tomte

		if [ $fix == "audiofix" ]; then
                    $install_cmd oem-audio-hda-daily-dkms
                fi

                if [ $fix == "tuxaudfix" ]; then
                    $install_cmd tuxedo-audio-fix
                fi

                if [ $fix == "tuxrestfix" ]; then
                    $install_cmd tuxedo-restore-audio-fix
                fi

                if [ $fix == "micfix" ]; then
                    $install_cmd tuxedo-micfix1
                fi

		if [ $fix == "amdgpu" ]; then
                    $install_cmd amdgpu-dkms
                fi
            fi

            if has_threeg; then
                echo "options usbserial vendor=0x12d1 product=0x15bb" > "/etc/modprobe.d/huawai-me936.conf"
                echo 'ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="12d1", ATTR{idProduct}=="15bb", ATTR{bNumConfigurations}=="3", ATTR{bConfigurationValue}!="3" ATTR{bConfigurationValue}="3"' > "/lib/udev/rules.d/77-mm-huawei-configuration.rules"
	    fi

            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7260-17.ucode
            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7265-17.ucode
            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7265D-21.ucode
            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-19.ucode
            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-20.ucode
            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-21.ucode
            #wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-22.ucode
            #cp iwlwifi*.ucode /lib/firmware/
            #rm -rf iwlwifi-*

            if has_kabylake_cpu;then
            wget https://www.tuxedocomputers.com/support/i915/kbl_dmc_ver1_01.bin
            wget https://www.tuxedocomputers.com/support/i915/kbl_guc_ver9_14.bin
            wget https://www.tuxedocomputers.com/support/i915/kbl_huc_ver02_00_1810.bin
            [ -d /lib/firmware/i915 ] || mkdir /lib/firmware/i915
            cp kbl*.bin /lib/firmware/i915/
            ln -sf /lib/firmware/i915/kbl_dmc_ver1_01.bin /lib/firmware/i915/kbl_dmc_ver1.bin
            ln -sf /lib/firmware/i915/kbl_guc_ver9_14.bin /lib/firmware/i915/kbl_guc_ver9.bin
            ln -sf /lib/firmware/i915/kbl_huc_ver02_00_1810.bin /lib/firmware/i915/kbl_huc_ver02.bin
            rm -rf kbl*.bin
            fi

            if has_skylake_cpu; then
            wget https://www.tuxedocomputers.com/support/i915/skl_dmc_ver1_26.bin
            wget https://www.tuxedocomputers.com/support/i915/skl_guc_ver6_1.bin
            [ -d /lib/firmware/i915 ] || mkdir /lib/firmware/i915
            cp skl*.bin /lib/firmware/i915
            ln -sf /lib/firmware/i915/skl_dmc_ver1_26.bin /lib/firmware/i915/skl_dmc_ver1.bin
            ln -sf /lib/firmware/i915/skl_guc_ver6_1.bin /lib/firmware/i915/skl_guc_ver6.bin
            rm -rf skl*.bin
            fi

            if [ -e "/sys/class/backlight/intel_backlight/max_brightness" ]; then
                cat /sys/class/backlight/intel_backlight/max_brightness > /sys/class/backlight/intel_backlight/brightness
            fi

            if pkg_is_installed ubuntu-desktop; then
                $install_cmd classicmenu-indicator
            fi
            ;;
        openSUSE*|SUSE*)
            $install_cmd gcc
            
            if [ $product == "P65_P67RGRERA" ]; then
                $install_cmd r8168-dkms-8.040.00-10.57.noarch
                echo "blacklist r8169" > "/etc/modprobe.d/99-local.conf"
            fi

	    if [ $fix == "tuxrestfix" ]; then
                    $install_cmd tuxedo-restore-audio-fix
            fi

            if [ $fix == "micfix" ]; then
                    $install_cmd tuxedo-micfix1
            fi

            $install_cmd  exfat-utils fuse-exfat realtek-clevo-pin-fix tuxedo-tomte tuxedo-keyboard edid-decode read-edid tuxedo-cc-wmi tuxedo-control-center
            echo "options tuxedo_keyboard mode=0 color_left=0xFFFFFF color_center=0xFFFFFF color_right=0xFFFFFF color_extra=0xFFFFFF brightness=200" > /etc/modprobe.d/tuxedo_keyboard.conf
            systemctl enable dkms
            ;;
    esac

    $install_cmd $PACKAGES
}

task_software_test() {
    case "$lsb_dist_id" in
        Ubuntu|LinuxMint|elementary*)
            pkg_is_installed tlp || return 1
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
do_task repository
do_task install_kernel
do_task grub
has_fingerprint_reader && do_task fingerprint
has_nvidia_gpu && do_task nvidia
do_task wallpaper
do_task software
do_task misc
do_task clean
do_task update

read -p "Press <ENTER> to reboot" >&3 2>&1
exec reboot
