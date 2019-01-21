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

cd "$(dirname "$0")" || return 0
SCRIPTPATH="$(readlink -f "$0")"
BASEDIR="$(dirname "$SCRIPTPATH")"

BASE_URL="https://raw.githubusercontent.com/tuxedocomputers/tuxedo.sh/master"

# additional packages that should be installed
PACKAGES=""
PACKAGES_UBUNTU=""
PACKAGES_SUSE=""

ERROR=0
trap 'ERROR=$(($? > $ERROR ? $? : $ERROR))' ERR
set errtrace
xset s off
xset -dpms

LSB_DIST_ID="$(lsb_release -si)"   # e.g. 'Ubuntu', 'LinuxMint', 'openSUSE project'
LSB_RELEASE="$(lsb_release -sr)"   # e.g. '13.04', '15', '12.3'
LSB_CODENAME="$(lsb_release -sc)"  # e.g. 'raring', 'olivia', 'Dartmouth'

APT_OPTS='-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew --fix-missing'
ZYPPER_OPTS='-n'

PRODUCT="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/product_name" | tr ' ,/-' '_')" # e.g. 'U931'
BOARD="$(sed -e 's/^\s*//g' -e 's/\s*$//g' "/sys/devices/virtual/dmi/id/board_name" | tr ' ,/-' '_')"

case "$PRODUCT" in
    U931|U953|INFINITYBOOK13V2|InfinityBook13V3|InfinityBook15*|Skylake_Platform)
        PRODUCT="U931"
        GRUB_TYPE="NOGRUB"
        ;;
    P65_67RS*|P65_67RP*|P65xRP|P67xRP|P65xH*|P65_P67H*)
        GRUB_TYPE="02GRUB"
        ;;
    P7xxDM*)
        GRUB_TYPE="NOGRUB"
        ;;
    P7xxTM*)
        GRUB_TYPE="03GRUB"
        ;;
    P775DM3*)
        GRUB_TYPE="01GRUB"
        ;;
    *) : ;;
esac

case "$BOARD" in
    P95*) fix="audiofix";;
    *) : ;;
esac

if [ "$EUID" -ne 0 ]; then
    echo "You aren't 'root', but '$(whoami)'. Aren't you?!"
    exec sudo "$0"
fi

exec 3>&1 &>tuxedo.log

if hash xterm 2>/dev/null; then
    exec xterm -geometry 150x50 -e tail -f tuxedo.log &
fi

echo "$(basename "$0")"
lsb_release -a

case "$LSB_DIST_ID" in
    Ubuntu)
        install_cmd="apt-get $APT_OPTS install"
        remove_cmd="apt-get $APT_OPTS remove --purge --auto-remove"
        upgrade_cmd="apt-get $APT_OPTS dist-upgrade"
        refresh_cmd="apt-get $APT_OPTS update"
        clean_cmd="apt-get -y clean"
        ;;
    openSUSE*|SUSE*)
        install_cmd="zypper $ZYPPER_OPTS install -l"
        remove_cmd="zypper $ZYPPER_OPTS remove -u"
        upgrade_cmd="zypper $ZYPPER_OPTS update -l"
        refresh_cmd="zypper $ZYPPER_OPTS refresh"
        clean_cmd="zypper $ZYPPER_OPTS clean --all"
        ;;
    *)
        echo "Unknown Distribution: '$LSB_DIST_ID'"
        ;;
esac

do_task() {
    error=0
    printf "%-16s " "$1" >&3
    echo "Calling task $1"
    task_${1}

    if [ $ERROR -eq 0 ] && task_${1}_test; then
        echo -e "\e[1;32mOK\e[0m" >&3
        echo "Task $1 OK"
    else
        echo -e "\e[1;31mFAILED\e[0m" >&3
        echo "Task $1 FAILED"
    fi
}

download_file() {
    local SOURCE_FILE="$1"
    local SOURCE_URL="$2"
    local TARGET="$3"

    local SOURCE=""
    if [ -f "$SOURCE_FILE" ] ; then
        SOURCE="file://$SOURCE_FILE"
    else
        SOURCE="$SOURCE_URL"
    fi

    curl -o- "$SOURCE" > "$TARGET"
}

pkg_is_installed() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]
            ;;
        openSUSE*|SUSE*)
            rpm -q "$1" >/dev/null
            ;;
    esac
}

has_nvidia_gpu() {
    lspci -nd 10de: | grep -q '030[02]:'
}

has_fingerprint_reader() {
    [ -x "$(which lsusb)" ] || $install_cmd usbutils
    lsusb -d 0483: || lsusb -d 147e: || lsusb -d 12d1: || lsusb -d 1c7a:0603
}

has_threeg() {
    [ -x "$(which lsusb)" ] || $install_cmd usbutils
    lsusb -d 12d1:15bb
}

task_clean() {
    $clean_cmd
    find /var/lib/apt/lists -type f -not -name 'lock' -exec rm -fv {} \; 2>/dev/null
}

task_clean_test() {
    return 0
}

task_update() {
    $refresh_cmd
    $upgrade_cmd
}

task_update_test() {
    return 0
}

task_init() {
    [ -x "$(which curl)" ] || $install_cmd curl
}

task_init_test() {
    [ -x "$(which curl)" ]
}

task_repository() {
    local REPO_TMP="$(mktemp -d)"

    case "$LSB_DIST_ID" in
        Ubuntu)
            local UBUNTU_KEYNAME="ubuntu.pub"
            local UBUNTU_KEYFILE_PATH="$REPO_TMP/$UBUNTU_KEYNAME"
            local UBUNTU_REPO="tuxedo-computers.list"
            local UBUNTU_REPO_FILEPATH="/etc/apt/sources.list.d/tuxedo-computers.list"

            download_file "$BASEDIR/keys/$UBUNTU_KEYNAME" "$BASE_URL/keys/$UBUNTU_KEYNAME" "$UBUNTU_KEYFILE_PATH"
            download_file"$BASEDIR/sourcelists/$UBUNTU_REPO" "$BASE_URL/sourcelists/$UBUNTU_REPO" "$UBUNTU_REPO_FILEPATH"

            sed -i -e 's/\${lsb_codename}/'"$LSB_CODENAME"'/g' "$UBUNTU_REPO_FILEPATH"

            apt-key add "$UBUNTU_KEYFILE_PATH"
            ;;
        openSUSE*|SUSE*)
            local SUSE_KEYNAME="suse.pub"
            local NVIDIA_KEYNAME="nvidia.pub"
            local SUSE_ISV_REPO="repo-isv-tuxedo.repo"
            local SUSE_NVIDIA_REPO="repo-nvidia-tuxedo.repo"

            local SUSE_KEYFILE_PATH="$REPO_TMP/$SUSE_KEYNAME"
            local NVIDIA_KEYFILE_PATH="$REPO_TMP/$NVIDIA_KEYNAME"

            download_file "$BASEDIR/keys/$SUSE_KEYNAME" "$BASE_URL/keys/$SUSE_KEYNAME" "$SUSE_KEYFILE_PATH"
            download_file "$BASEDIR/keys/$NVIDIA_KEYNAME" "$BASE_URL/keys/$NVIDIA_KEYNAME" "$NVIDIA_KEYFILE_PATH"

            download_file "$BASEDIR/sourcelists/$SUSE_ISV_REPO" "$BASE_URL/sourcelists/$SUSE_ISV_REPO" "/etc/zypp/repos.d/repo-isv-tuxedo.repo"
            download_file "$BASEDIR/sourcelists/$SUSE_NVIDIA_REPO" "$BASE_URL/sourcelists/$SUSE_NVIDIA_REPO" "/etc/zypp/repos.d/repo-nvidia-tuxedo.repo"

            rpmkeys --import "$SUSE_KEYFILE_PATH"
            rpmkeys --import "$NVIDIA_KEYFILE_PATH"
            ;;
    esac

    rm -rf "$REPO_TMP"
}

task_repository_test() {
    case "$LSB_DIST_ID" in
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

task_install_kernel() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            case "$LSB_CODENAME" in
                xenial)  $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                yakkety) $install_cmd linux-image-4.11.8-041108-generic linux-headers-4.11.8-041108-generic linux-headers-4.11.8-041108;;
                zesty)   $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                artful)  $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                bionic)  $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                *)       $install_cmd linux-generic ;;
            esac
            ;;
        openSUSE*|SUSE*)
            case "$LSB_RELEASE" in
                42.1) $install_cmd -f kernel-default-4.4.0-8.1.x86_64 kernel-default-devel-4.4.0-8.1.x86_64 kernel-firmware;;
                *)    : ;;
            esac
            ;;
    esac
}

task_install_kernel_test() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            case "$LSB_CODENAME" in
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

task_grub() {
    local DEFAULT_GRUB="/etc/default/grub"

    case "$LSB_DIST_ID" in
        Ubuntu)
            case "$GRUB_TYPE" in
                01GRUB)
                    GRUB_OPTIONS=("acpi_osi=Linux" "acpi_backlight=vendor")
                    ;;
                02GRUB)
                    GRUB_OPTIONS=("acpi_os_name=Linux" "acpi_osi=" "acpi_backlight=vendor" "i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                03GRUB)
                    GRUB_OPTIONS=("acpi_osi=" "acpi_os_name=Linux")
                    ;;
                *)
                    GRUB_OPTIONS=("acpi_osi=" "acpi_os_name=Linux" "acpi_backlight=vendor")
                    ;;
            esac

            for OPTION in ${GRUB_OPTIONS[*]}; do
                if ! grep -q "$OPTION" "$DEFAULT_GRUB"; then
                    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"\(.*\)"/"\1 '"$OPTION"'"/' "$DEFAULT_GRUB"
                fi
            done

            if has_nvidia_gpu; then
                sed -i '/^GRUB_CMDLINE_LINUX=/ s/nomodeset//' "$DEFAULT_GRUB"
            fi

            sed -i '/^GRUB_CMDLINE_LINUX=/,1 aGRUB_GFXPAYLOAD_LINUX=1920*1080' "$DEFAULT_GRUB"
            update-grub
            ;;

        openSUSE*|SUSE*)
            case "$GRUB_TYPE" in
                01GRUB)
                    GRUB_OPTIONS=("loglevel=0" "acpi_osi=Linux" "acpi_backlight=vendor")
                    ;;
                02GRUB)
                    GRUB_OPTIONS=("loglevel=0" "acpi_os_name=Linux" "acpi_osi=" "acpi_backlight=vendor" "i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                03GRUB)
                    GRUB_OPTIONS=("loglevel=0" "acpi_osi=" "acpi_os_name=Linux")
                    ;;
                *)
                    GRUB_OPTIONS=("loglevel=0" "acpi_osi=" "acpi_os_name=Linux" "acpi_backlight=vendor")
                    ;;
            esac

            for OPTION in ${GRUB_OPTIONS[*]}; do
                if ! grep -q "$OPTION" "$DEFAULT_GRUB"; then
                    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"\(.*\)"/"\1 '"$OPTION"'"/' "$DEFAULT_GRUB"
                fi
            done

            grub2-mkconfig -o /boot/grub2/grub.cfg
            ;;
    esac
}

task_grub_test() {
    return 0
}

task_fingerprint() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            $install_cmd libfprint0 libpam-fprintd fprint-demo
            ;;
        openSUSE*|SUSE*)
            $install_cmd libfprint0 pam_fprint
            ;;
    esac
}

task_fingerprint_test() {
    case "$LSB_DIST_ID" in
        Ubuntu)          pkg_is_installed fprint-demo && pkg_is_installed libfprint0;;
        openSUSE*|SUSE*) pkg_is_installed libfprint0;;
    esac
}

task_nvidia() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            if [ "$LSB_RELEASE" == "16.04" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ "$LSB_RELEASE" == "16.10" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ "$LSB_RELEASE" == "17.04" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ "$LSB_RELEASE" == "18.04" ]; then
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

            if lspci -nd '10de:' | grep -q '030[02]:' && lspci -nd '8086:' | grep -q '0300:'; then
                $install_cmd nvidia-computeG04 nvidia-gfxG04-kmp-default nvidia-glG04 x11-video-nvidiaG04 suse-prime
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 afi' "/etc/X11/xdm/Xsetup"
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 a\.\/etc\/X11\/xinit\/xinitrc\.d\/prime-offload\.sh' "/etc/X11/xdm/Xsetup"
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 athen' "/etc/X11/xdm/Xsetup"
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 aif\ \[\ \-f\ /etc/X11/xinit/xinitrc\.d/prime-offload\.sh\ \]\;' "/etc/X11/xdm/Xsetup"
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
    case "$LSB_DIST_ID" in
        Ubuntu)
            pkg_is_installed nvidia-390 || pkg_is_installed nvidia-driver-390 || pkg_is_installed nvidia-381
            ;;
        openSUSE*|SUSE*)
            pkg_is_installed nvidia-computeG04
            ;;
    esac
}

task_firmware() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            if [ "$LSB_RELEASE" == "16.04" ]; then
                download_file "$BASEDIR/iwlwifi/iwlwifi-3160-17.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-3160-17.ucode" "/lib/firmware/iwlwifi-3160-17.ucode"
            fi

            if [ "$LSB_RELEASE" == "18.04" ]; then
                if [ "$fix" == "audiofix" ]; then
                    $install_cmd oem-audio-hda-daily-dkms
                fi
            fi

            if has_threeg; then
                echo "options usbserial vendor=0x12d1 product=0x15bb" > "/etc/modprobe.d/huawai-me936.conf"
                echo 'ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="12d1", ATTR{idProduct}=="15bb", ATTR{bNumConfigurations}=="3", ATTR{bConfigurationValue}!="3" ATTR{bConfigurationValue}="3"' > "/lib/udev/rules.d/77-mm-huawei-configuration.rules"
            fi

            download_file "$BASEDIR/iwlwifi/iwlwifi-7260-17.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7260-17.ucode" "/lib/firmware/iwlwifi-7260-17.ucode"
            download_file "$BASEDIR/iwlwifi/iwlwifi-7265-17.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7265-17.ucode" "/lib/firmware/iwlwifi-7265-17.ucode"
            download_file "$BASEDIR/iwlwifi/iwlwifi-7265D-21.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-7265D-21.ucode" "/lib/firmware/iwlwifi-7265D-21.ucode"
            download_file "$BASEDIR/iwlwifi/iwlwifi-8000C-19.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-19.ucode" "/lib/firmware/iwlwifi-8000C-19.ucode"
            download_file "$BASEDIR/iwlwifi/iwlwifi-8000C-20.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-20.ucode" "/lib/firmware/iwlwifi-8000C-20.ucode"
            download_file "$BASEDIR/iwlwifi/iwlwifi-8000C-21.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-21.ucode" "/lib/firmware/iwlwifi-8000C-21.ucode"
            download_file "$BASEDIR/iwlwifi/iwlwifi-8000C-22.ucode" "https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-8000C-22.ucode" "/lib/firmware/iwlwifi-8000C-22.ucode"

            [ -d /lib/firmware/i915 ] || mkdir /lib/firmware/i915
            download_file "$BASEDIR/i915/kbl_dmc_ver1_01.bin" "https://www.tuxedocomputers.com/support/i915/kbl_dmc_ver1_01.bin" "/lib/firmware/i915/kbl_dmc_ver1_01.bin"
            download_file "$BASEDIR/i915/skl_dmc_ver1_26.bin" "https://www.tuxedocomputers.com/support/i915/skl_dmc_ver1_26.bin" "/lib/firmware/i915/skl_dmc_ver1_26.bin"
            download_file "$BASEDIR/i915/skl_guc_ver6_1.bin" "https://www.tuxedocomputers.com/support/i915/skl_guc_ver6_1.bin" "/lib/firmware/i915/skl_guc_ver6_1.bin"
            ln -sf "/lib/firmware/i915/kbl_dmc_ver1_01.bin" "/lib/firmware/i915/kbl_dmc_ver1.bin"
            ln -sf "/lib/firmware/i915/skl_dmc_ver1_26.bin" "/lib/firmware/i915/skl_dmc_ver1.bin"
            ln -sf "/lib/firmware/i915/skl_guc_ver6_1.bin" "/lib/firmware/i915/skl_guc_ver6.bin"

            $install_cmd r8168-dkms mesa-utils
            ;;
        openSUSE*|SUSE*)
            if [ "$PRODUCT" == "P65_P67RGRERA" ]; then
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
    case "$LSB_DIST_ID" in
        Ubuntu)
            $install_cmd tlp

            if [ "$LSB_RELEASE" == "15.10" ]; then
                sed -i "s#\(^AUTOSUSPEND_RUNTIME_DEVTYPE_BLACKLIST=\).*#\1usbhid#" /etc/laptop-mode/conf.d/runtime-pm.conf
            fi

            if [ -e "/sys/class/backlight/intel_backlight/max_brightness" ]; then
                cat /sys/class/backlight/intel_backlight/max_brightness > /sys/class/backlight/intel_backlight/brightness
            fi

            if [ -n "$PACKAGES_UBUNTU" ]; then
                $install_cmd $PACKAGES_UBUNTU
            fi

            $remove_cmd unity-webapps-common app-install-data-partner ubuntu-web-launchers apport apport-symptoms
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
    case "$LSB_DIST_ID" in
        Ubuntu|LinuxMint|elementary*)
            pkg_is_installed tlp || return 1
            ;;
    esac

    for PACKAGE in $PACKAGES; do
        pkg_is_installed "$PACKAGE" || return 1
    done

    return 0
}

task_wallpaper() {
    case "$LSB_DIST_ID" in
        Ubuntu)          $install_cmd tuxedo-wallpapers;;
        openSUSE*|SUSE*) $install_cmd tuxedo-one-wallpapers;;
    esac

    if pkg_is_installed ubuntu-desktop; then
        local FILENAME="30_tuxedo-settings.gschema.override"
        download_file "$BASEDIR/files/$FILENAME" "$BASE_URL/files/$FILENAME" "/usr/share/glib-2.0/schemas/$FILENAME"
        glib-compile-schemas /usr/share/glib-2.0/schemas
    elif pkg_is_installed kubuntu-desktop; then
        local FILENAME="80-tuxedo.js"
        download_file "$BASEDIR/files/$FILENAME" "$BASE_URL/files/$FILENAME" "/usr/share/glib-2.0/schemas/$FILENAME"
    elif pkg_is_installed xubuntu-desktop; then
        local FILENAME="xfce4-desktop.xml"
        download_file "$BASEDIR/files/$FILENAME" "$BASE_URL/files/$FILENAME" "/usr/share/glib-2.0/schemas/$FILENAME"
    fi
}

task_wallpaper_test() {
    pkg_is_installed tuxedo-wallpapers || pkg_is_installed tuxedo-one-wallpapers
}

task_misc() {
    case "$LSB_DIST_ID" in
        Ubuntu)
            if ! [ -x "$(which gsettings)" ]; then
                echo "gsettings not found or not executable. Skipping misc!"
                return 1
            fi

            sudo -u "$(logname)" -- /bin/bash <<'EOSU'
            schema="com.canonical.Unity.Lenses"
            val="['more_suggestions-amazon.scope', 'more_suggestions-u1ms.scope', 'more_suggestions-populartracks.scope', 'music-musicstore.scope', 'more_suggestions-ebay.scope', 'more_suggestions-ubuntushop.scope', 'more_suggestions-skimlinks.scope']"

            if gsettings writable "$schema" disabled-scopes; then
                gsettings set "$schema" disabled-scopes "$val"
            fi

            if [ "$(lsb_release -sr)" == "18.04" ] && gsettings writable org.gnome.desktop.peripherals.touchpad click-method; then
                gsettings set org.gnome.desktop.peripherals.touchpad click-method areas
            fi
EOSU
            ;;
    esac
}

task_misc_test() {
    return 0
}

do_task clean
do_task update
do_task init
do_task repository
do_task update
do_task install_kernel
do_task grub
has_fingerprint_reader && do_task fingerprint
has_nvidia_gpu && do_task nvidia
do_task firmware
do_task software
do_task wallpaper
do_task misc
do_task clean
do_task update

read -p "Press <ENTER> to reboot" >&3 2>&1
exec reboot
