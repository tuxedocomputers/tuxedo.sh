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

# Version: 3.43

APT_CACHE_HOSTS="192.168.178.110 192.168.23.231"
APT_CACHE_PORT=3142
# additional packages that should be installed
PACKAGES="cheese pavucontrol brasero gparted pidgin vim obexftp ethtool xautomation curl linssid unrar"

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
    *) 
        echo "nichts" >/dev/null
        ;;
esac

case $board in
    P95*) 
        fix="audiofix"
        ;;
    *) 
        echo "nichts" >/dev/null
        ;;
esac

cd $(dirname $0)

if [ "$(id -u)" -ne 0 ]; then
    echo "You aren't 'root', but '$(whoami)'. Aren't you?!"
    exec sudo su -c "bash '$(basename $0)'"
fi

exec 3>&1 &>tuxedo.log

if hash xterm 2>/dev/null; then
    exec xterm -geometry 150x50 -e tail -f tuxedo.log &
fi

echo $(basename $0)
lsb_release -a

case "$lsb_dist_id" in
    Ubuntu)
        install_cmd="apt-get $apt_opts install"
        upgrade_cmd="apt-get $apt_opts dist-upgrade"
        refresh_cmd="apt-get $apt_opts update"
        clean_cmd="apt-get -y clean"
        ;;
    openSUSE)
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
    lsusb -d 12d1:1404
}

add_apt_repository() {
    add-apt-repository -y $1
}

pkg_is_installed() {
    case "$lsb_dist_id" in
        Ubuntu)
            [ "$(dpkg-query -W -f='${Status}' $1 2>/dev/null)" = "install ok installed" ]
            ;;
        openSUSE)
            rpm -q $1 >/dev/null
            ;;
    esac
}

task_grub() {
    local default_grub=/etc/default/grub

    case "$lsb_dist_id" in
        Ubuntu)
            case "$grubakt" in
                01GRUB)
                    grub_options = ("acpi_osi=Linux" "acpi_backlight=vendor")
                    ;;
                02GRUB)
                    grub_options = ("acpi_os_name=Linux" "acpi_osi=" "acpi_backlight=vendor" "i8042.reset" "i8042.nomux" "i8042.nopnp" "i8042.noloop")
                    ;;
                03GRUB)
                    grub_options = ("acpi_osi=" "acpi_os_name=Linux")
                    ;;
                *)
                    grub_options = ("acpi_osi=" "acpi_os_name=Linux" "acpi_backlight=vendor")
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
    true
}

task_nvidia() {
    case "$lsb_dist_id" in
        Ubuntu)
            if [ $lsb_release == "16.04" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ $lsb_release == "16.10" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ $lsb_release == "17.04" ]; then
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            elif [ $lsb_release == "18.04" ]; then
                $install_cmd nvidia-driver-390 mesa-utils nvidia-prime vdpau-va-driver python-appindicator python-cairo python-gtk2
            else
                $install_cmd nvidia-390 mesa-utils nvidia-prime
            fi
            ;;
        openSUSE)
            if $(lspci -nd '10de:' | grep -q '030[02]:' && lspci -nd '8086:' | grep -q '0300:'); then
                $install_cmd nvidia-computeG04 nvidia-gfxG04-kmp-default nvidia-glG04 x11-video-nvidiaG04 suse-prime
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 afi' /etc/X11/xdm/Xsetup
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 a\.\/etc\/X11\/xinit\/xinitrc\.d\/prime-offload\.sh' /etc/X11/xdm/Xsetup
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 athen' /etc/X11/xdm/Xsetup
                sed -i '/^\.\ \/etc\/sysconfig\/displaymanager/,1 aif\ \[\ \-f\ /etc/X11/xinit/xinitrc\.d/prime-offload\.sh\ \]\;' /etc/X11/xdm/Xsetup
                sed -i -e 's/Intel/modesetting/' "/etc/prime/prime-offload.sh"
                sed -i -e 's/Driver\ \"intel\"/Driver\ \"modesetting\"/' "/etc/prime/xorg.conf"
            else
                $install_cmd dkms nvidia-computeG04 nvidia-gfxG04-kmp-default nvidia-glG04 x11-video-nvidiaG04
            fi                        
            ;;
        *)
            echo "nix"  >/dev/null
            ;;
    esac
}

task_nvidia_test() {
    case "$lsb_dist_id" in
        Ubuntu)
            pkg_is_installed nvidia-390 || pkg_is_installed nvidia-driver-390 || pkg_is_installed nvidia-381
            ;;
        openSUSE*)
            pkg_is_installed nvidia-computeG04
            ;;
    esac
}

task_fingerprint() {
    case "$lsb_dist_id" in
        Ubuntu)
            $install_cmd libfprint0 libpam-fprintd fprint-demo
            ;;
        openSUSE)
            $install_cmd libfprint0 pam_fprint
            ;;
    esac
}

task_fingerprint_test() {
    case "$lsb_dist_id" in
        Ubuntu) pkg_is_installed fprint-demo && pkg_is_installed libfprint0;;
        openSUSE) pkg_is_installed libfprint0;;
    esac
}

task_wallpaper() {
    case "$lsb_dist_id" in
        Ubuntu) $install_cmd tuxedo-wallpapers;;
        openSUSE) $install_cmd tuxedo-one-wallpapers;;
    esac

    if pkg_is_installed ubuntu-desktop; then
        cat <<-__EOF__ >/usr/share/glib-2.0/schemas/30_tuxedo-settings.gschema.override
[org.gnome.desktop.background]
picture-uri='file:///usr/share/tuxedo-wallpapers/tuxedo-background_10.jpg'
__EOF__
        glib-compile-schemas /usr/share/glib-2.0/schemas
    elif pkg_is_installed kubuntu-desktop; then
        cat <<-__EOF__ >/usr/share/kde4/apps/plasma-desktop/init/80-tuxedo.js
a = activities()

for (i in a) {
    a[i].wallpaperPlugin    = 'image'
    a[i].wallpaperMode      = 'SingleImage'
    a[i].currentConfigGroup = Array('Wallpaper', 'image')
    a[i].writeConfig('wallpaper', '/usr/share/wallpapers/Tuxedo_10/contents/images/1920x1080.jpg')
    a[i].writeConfig('wallpaperposition', '0')
}
__EOF__
    elif pkg_is_installed xubuntu-desktop; then
        cat <<-__EOF__ >/etc/xdg/xdg-xubuntu/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-desktop" version="1.0">
    <property name="desktop-icons" type="empty">
        <property name="style" type="int" value="2"/>
        <property name="file-icons" type="empty">
            <property name="show-home" type="bool" value="true"/>
            <property name="show-filesystem" type="bool" value="true"/>
            <property name="show-removable" type="bool" value="true"/>
            <property name="show-trash" type="bool" value="true"/>
        </property>
    </property>
    <property name="backdrop" type="empty">
        <property name="screen0" type="empty">
            <property name="monitor0" type="empty">
                <property name="image-path" type="string" value="/usr/share/xfce4/backdrops/tuxedo-background_10.jpg"/>
                <property name="image-show" type="bool" value="true"/>
            </property>
            <property name="monitor1" type="empty">
                <property name="image-path" type="string" value="/usr/share/xfce4/backdrops/tuxedo-background_10.jpg"/>
                <property name="image-show" type="bool" value="true"/>
            </property>
        </property>
    </property>
</channel>
__EOF__
    fi
}

task_wallpaper_test() {
    pkg_is_installed tuxedo-wallpapers || pkg_is_installed tuxedo-one-wallpapers
}

task_misc() {
    case "$lsb_dist_id" in
        Ubuntu)
            local schema="com.canonical.Unity.Lenses"
            local key="disabled-scopes"
            local val="['more_suggestions-amazon.scope', 'more_suggestions-u1ms.scope', 'more_suggestions-populartracks.scope', 'music-musicstore.scope', 'more_suggestions-ebay.scope', 'more_suggestions-ubuntushop.scope', 'more_suggestions-skimlinks.scope']"
            local schema_dir=/usr/share/glib-2.0/schemas

            local uid=1000
            local user_name=$(getent passwd | awk -v uid=$uid 'BEGIN { FS=":" } { if ($3 == uid) print $1 }')

            if [ -x $(which gsettings) ] && su -c"gsettings writable $schema $key" $user_name; then
                su -c"gsettings set $schema $key \"$val\"" $user_name
            fi
            
            #AH
            if [ -x $(which gsettings) ] && su -c"gsettings writable $schema remote-content-search" $user_name; then
                su -c"gsettings set $schema remote-content-search none" $user_name
            fi
            ;;
    esac
}

task_misc_test() {
    true
}

task_repository() {
    case "$lsb_dist_id" in
        Ubuntu)
            if ! [ -f /etc/apt/sources.list.d/tuxedo-computers.list ] ; then
                cat <<-__EOF__ >"/etc/apt/sources.list.d/tuxedo-computers.list"
deb http://deb.tuxedocomputers.com/ubuntu $lsb_codename main
deb http://intel.tuxedocomputers.com/ubuntu $lsb_codename main
deb http://graphics.tuxedocomputers.com/ubuntu $lsb_codename main
deb http://kernel.tuxedocomputers.com/ubuntu $lsb_codename main
__EOF__
            fi
            ;;
        openSUSE)
            cat <<-__EOF__ >"/etc/zypp/repos.d/repo-isv-tuxedo.repo"
[isv_TUXEDO]
name=isv:TUXEDO (openSUSE_Leap_15.0)
enabled=1
autorefresh=0
baseurl=http://download.opensuse.org/repositories/isv:/TUXEDO/openSUSE_Leap_15.0/
type=rpm-md
gpgcheck=1
gpgkey=http://download.opensuse.org/repositories/isv:/TUXEDO/openSUSE_Leap_15.0/repodata/repomd.xml.key
__EOF__
            cat <<-__EOF__ >"/etc/zypp/repos.d/repo-nvidia-tuxedo.repo"
[repo-nvidia-tuxedo]
name=TUXEDO Computers - 15.0 NVIDIA
baseurl=http://nvidia.tuxedocomputers.com/opensuse/15.0
path=/
gpgkey=http://nvidia.tuxedocomputers.com/opensuse/15.0/repodata/repomd.xml.key
gpgcheck=1
enabled=1
autorefresh=1
__EOF__
            local tmp="$(mktemp)"
            cat <<-__EOF__ >"$tmp"
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1
Comment: repo-nvidia-tuxedo 

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
=5MIM
-----END PGP PUBLIC KEY BLOCK-----

-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2.0.15 (GNU/Linux)
Comment: isv_TUXEDO

mQENBFp8S6gBCAC/dp1P7USJIIOTZTXcFHZoHPNaqX0rh5MqxFZMjH2Rq7JPHoa9
4jY02UDEe6x4SOf8Ev+vZVxwQxpWgUYDH0yz8gf5psoO5Q+Vfwo2OidQw+WOIflj
3moPVcqEysKuUvznHM9I4SWSE6dP2geD15OVt+9/HGLAjhw3V0iE46qAE4ijDSNA
FpE13yGqsQYKaTgLHTAl664P4FTuewuoBmsDa3LONLlk1ZGCqVI0kj81RR4Pu1ll
7REIsYLWZ4JpqRfOkwWov7wcfL8HfQRfXur2nj9FMqZVjcxdhYTmspAIX6so5Blw
DNRkA9lKvFR0e64xEN1KZYE1/XXbxQq6PjtxABEBAAG0NmlzdjpUVVhFRE8gT0JT
IFByb2plY3QgPGlzdjpUVVhFRE9AYnVpbGQub3BlbnN1c2Uub3JnPokBPgQTAQgA
KAUCWnxLqAIbAwUJBB6wAAYLCQgHAwIGFQgCCQoLBBYCAwECHgECF4AACgkQRpdZ
JezqOxBcKAgAo0TgaMbvgsEAtuCE2/m6UZQdk+hAt2jBHpBtiJJEI9WCQsepQhx3
gDQkz6b9sWd+6aAm/q97/Uq3Wz7xyKZiUN9GTHeFN3R3nktP8iFG4CkhD6aksnYh
pyivRKghPU5kZ40SHIVYnXX63pdbnslf7v+DyJz3vSDrwdEnDwe236Cpsb7OsFyw
rj3r+bCkqfpfmHKD653GbSOwxWPJRrUo6ZPzKDwE42KbQBPUmk/tgpIm+yP/tNZP
PhnMiQoMnV2536L5MB4jk0W2hLdR3xWWfknf4k01WNdqhmhbMIasumkiGRuevOP6
skDTqk/3PTLlmd6+2vSN9f68+nmkR0XhR4hGBBMRAgAGBQJafEuoAAoJEDswEbdr
nWUj880AoIVFwobHRIRA7mWLk9OvQtc1kKwmAJ9WMC9m0pO/HD6IPj4V5C0MhPxW
4g==
=OuHm
-----END PGP PUBLIC KEY BLOCK-----
__EOF__
            rpmkeys --import "$tmp" && rm "$tmp"
            ;;
    esac

    case "$lsb_dist_id" in
        Ubuntu)
            # pub   2048R/B45D479D 2014-11-24
            # uid   TUXEDO Computers GmbH (www.tuxedocomputers.com) <tux@tuxedocomputers.com>
            # sub   2048R/7B189DC4 2014-11-24
            cat <<-__EOF__ | apt-key add -
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1
Comment: deb.tuxedocomputers.com 4096R/54840598 4096R/A5842AD4

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
=5MIM
-----END PGP PUBLIC KEY BLOCK-----
__EOF__
            ;;
        openSUSE)
            local tmp="$(mktemp)"
            # pub   2048R/45E3D129 2014-06-27 [expires: 2017-06-26]
            # uid                  Andreas Hemmrich (TUXEDO Computers GmbH) <ah@tuxedocomputers.com>
            # uid                  Christoph Jaeger (TUXEDO Computers GmbH) <cj@tuxedocomputers.com>
            cat <<-__EOF__ >"$tmp"
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.14 (GNU/Linux)
Comment: 2048R/45E3D129

mQENBFOtQaYBCACbkQDjjxYQUkb7BbJPXraqXZxKRyfGBSdSVlSRRIeGUlwkO/8q
e+uyDOD8Q1KJg7WZd9wa3lGhSYQLVoO0YL0UBIdYtxIuskE6MWIVlfadZdlQuvSI
pxciSIfISTD6Zqk8GqdP7JnSLjPOra3smlQguKQlrDkxWJtkF2CIfdC2p24FsC/R
GiSOEHaOXQNqPPpBiWD3L/BZFHeT7zkl2eBqZ8DsgMu3Cuz0CieOr/hcNfUV/n8B
XNUdpuJT1Cu4q9FVCHdOrlsgu0Z5bM5Wt1XB4WPDh5jGoPREHIT8gtDhtP6nDz7R
ERHd8RedrVvL1DPQLZwiCoKreO4g3jpGB0ClABEBAAG0QUFuZHJlYXMgSGVtbXJp
Y2ggKFRVWEVETyBDb21wdXRlcnMgR21iSCkgPGFoQHR1eGVkb2NvbXB1dGVycy5j
b20+iQFBBBMBAgArAhsDBQkFo5qABgsJCAcDAgYVCAIJCgsEFgIDAQIeAQIXgAUC
VBa9sgIZAQAKCRDe47N+RePRKXxjB/93QTyEAGmz5lQ0/IOXqDq5fBYR9CELUPQI
8zeqD7xrostP0GLjMujRjHyy8O7CAqTOEs7GZOCJ8VkWgQ6txV8oAbQt3gAMNDiN
qeekyecRA2FXA8u1pINv8satddiZEPe9+Q+9RdkAmZGXbsqRz1wKAfvlKY+Wt0fN
CRliEYIIcGH19fmOaW7t0QxDYCsoNqIIJT+KhZCIrqNXn4xz74ZPSKHOonfVGYw6
T6qls0ktIbUn9JXdP9P2JcZywpxpE8IgqGN0Fps71URbt+xtQw8TU9zw7eWR7+Oo
AOrvOsEggiD0FqvtSDBXZyGBk7qry6ODG9/hkMYSroZmEesrFbYGtEFDaHJpc3Rv
cGggSmFlZ2VyIChUVVhFRE8gQ29tcHV0ZXJzIEdtYkgpIDxjakB0dXhlZG9jb21w
dXRlcnMuY29tPokBPgQTAQIAKAUCU61BpgIbAwUJBaOagAYLCQgHAwIGFQgCCQoL
BBYCAwECHgECF4AACgkQ3uOzfkXj0Skmiwf9FnaEvDONaEY0DjYP6g69RjnPHQ1r
VftMc9Rj8GX1wmZvYEjKICLPT95MUExbks0vN554rRbr4ZjjYn9DDPqYLjz4CFnm
zsUoNWQZHjIJqpR2KABBvpWXSESEo/SJ1Xd8Kvz4aDFfQKHh1WBDea6NDgNwz6n/
6c9QYNGKrHNywxyzxvBpxN0IN9T2USCTIFzyTeGbRBW75FqT/iKd444BZiqLV3nx
F/+P9/IaJp+/C0OroCf06KzgJqIvQ4jWqav9riPSO1mYjszCmXF5to9TySzXMOX5
WzcaWWHZQT2K6lG3kFGr0XRLi6EdVsGeJDFwJ/MYBHxR3tdTohw0o7WLUA==
=XwJ1
-----END PGP PUBLIC KEY BLOCK-----
__EOF__
            rpmkeys --import "$tmp"
            rm -f "$tmp"
            ;;
    esac
}

task_repository_test() {
    true
}

task_update() {
    $refresh_cmd
    $upgrade_cmd
}

task_update_test() {
    true
}

task_install_kernel() {
    $refresh_cmd
    $upgrade_cmd
    case "$lsb_dist_id" in
        Ubuntu)
            case "$lsb_codename" in
                xenial|zesty|artful|bionic) $install_cmd linux-generic linux-image-generic linux-headers-generic linux-tools-generic;;
                yakkety) $install_cmd linux-image-4.11.8-041108-generic linux-headers-4.11.8-041108-generic linux-headers-4.11.8-041108;;
                *) $install_cmd linux-generic ;;
            esac
            ;;
        openSUSE*|SUSE*)
            case "$lsb_release" in
                42.1) $install_cmd -f kernel-default-4.4.0-8.1.x86_64 kernel-default-devel-4.4.0-8.1.x86_64 kernel-firmware;;
                *) echo "nichts" >/dev/null;;
            esac
            ;;
    esac
}

task_install_kernel_test() {
    case "$lsb_dist_id" in
        Ubuntu)
            case "$lsb_codename" in
                xenial) pkg_is_installed linux-generic;;
                yakkety) pkg_is_installed linux-image-4.11.8-041108-generic;;
                zesty) pkg_is_installed linux-image-generic;;
                artful) pkg_is_installed linux-image-generic;;
                bionic) pkg_is_installed linux-image-generic;;
                *) pkg_is_installed linux-generic || return 1 ;;
            esac
            ;;
        openSUSE*|SUSE*)
            pkg_is_installed kernel-default || return 1
            ;;
    esac
    true
}

task_trim() {
    while read device mountpoint fstype _; do
        [ -x "$(which hdparm)" ] || $install_cmd hdparm
        if [ $fstype = "ext4" ] && hdparm -I $device | grep -qiw 'trim'; then
            fstrim -v $mountpoint
            tune2fs -o discard $device
        fi
    done </proc/mounts
}

task_trim_test() {
    true
}

task_software() {
    case "$lsb_dist_id" in
        Ubuntu)
            mkdir -p /etc/laptop-mode/conf.d && touch /etc/laptop-mode/conf.d/ethernet.conf
            echo "CONTROL_ETHERNET=0" > /etc/laptop-mode/conf.d/ethernet.conf
            $install_cmd laptop-mode-tools xbacklight exfat-fuse exfat-utils gstreamer1.0-libav libgtkglext1 mesa-utils gnome-tweaks 
            
            if [ $lsb_release == "15.10" ]; then
                sed -i "s#\(^AUTOSUSPEND_RUNTIME_DEVTYPE_BLACKLIST=\).*#\1usbhid#" /etc/laptop-mode/conf.d/runtime-pm.conf
            fi

            apt-get -y remove unity-webapps-common app-install-data-partner apport ureadahead

            if [ $lsb_release == "16.04" ]; then
                wget https://www.tuxedocomputers.com/support/iwlwifi/iwlwifi-3160-17.ucode
            fi

            if [ $lsb_release == "18.04" ]; then
                if [ $fix == "audiofix" ]; then
                    $install_cmd oem-audio-hda-daily-dkms
                fi
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
            mkdir /lib/firmware/i915
            cp kbl*.bin /lib/firmware/i915/
            cp skl*.bin /lib/firmware/i915
            ln -sf /lib/firmware/i915/kbl_dmc_ver1_01.bin /lib/firmware/i915/kbl_dmc_ver1.bin
            ln -sf /lib/firmware/i915/skl_dmc_ver1_26.bin /lib/firmware/i915/skl_dmc_ver1.bin
            ln -sf /lib/firmware/i915/skl_guc_ver6_1.bin /lib/firmware/i915/skl_guc_ver6.bin
            rm -rf kbl*.bin
            rm -rf skl*.bin

            if [ -e "/sys/class/backlight/intel_backlight/max_brightness" ]; then
                cat /sys/class/backlight/intel_backlight/max_brightness > /sys/class/backlight/intel_backlight/brightness
            fi

            if pkg_is_installed ubuntu-desktop; then
                $install_cmd classicmenu-indicator
            fi
            ;;
        openSUSE)
            if [ $product == "P65_P67RGRERA" ]; then
                $install_cmd r8168-dkms-8.040.00-10.57.noarch
                echo "blacklist r8169" > "/etc/modprobe.d/99-local.conf"
            fi

            $install_cmd  exfat-utils fuse-exfat
            ;;
    esac

    $install_cmd $PACKAGES
}

task_software_test() {
    case "$lsb_dist_id" in
        Ubuntu|LinuxMint|elementary*)
            pkg_is_installed laptop-mode-tools || return 1
            ;;
    esac

    for p in $PACKAGES; do
        pkg_is_installed $p || return 1
    done

    true
}

task_clean() {
    $clean_cmd
    find /var/lib/apt/lists -type f -exec rm -fv {} \; 2>/dev/null
}

task_clean_test() {
    true
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

trap "rm -f $apt_conf_proxy $apt_sources_list; exit" ABRT EXIT HUP INT QUIT

[ -x $(which nc) ] || $install_cmd netcat-openbsd

proxy=
for host in $APT_CACHE_HOSTS; do
    echo "Trying to reach proxy $host ..."
    if ping -w 2 $host && nc -zv $host $APT_CACHE_PORT 2>&1 | grep -q 'Connection.*succeeded!'; then
        proxy=$host
        break
    fi
done

if [ "$proxy" ]; then
    apt_conf_proxy=/etc/apt/apt.conf.d/00proxy
    echo "Using apt-cache $proxy:$APT_CACHE_PORT" >&3
    case "$lsb_dist_id" in
        Ubuntu|LinuxMint|elementary*)
            cat >"$apt_conf_proxy" <<-__EOF__
Acquire::http { Proxy "http://$proxy:$APT_CACHE_PORT"; };
__EOF__
            ;;
        openSUSE*|SUSE*)
            export http_proxy=http://$proxy:$APT_CACHE_PORT
            ;;
    esac
else
    echo "apt-cache NOT available" >&3
fi

do_task clean
do_task update
do_task repository
do_task install_kernel
#do_task trim
do_task grub

case "$lsb_dist_id" in
    Ubuntu|LinuxMint|elementary*)
        [ "$lsb_codename" = "quantal" -o "$lsb_codename" = "raring" -o "$lsb_codename" = "nadia" -o "$lsb_codename" = "olivia" ] && do_task saucy_kernel
        has_fingerprint_reader && do_task fingerprint
        ;;
    openSUSE*)
        ;;
    SUSE*)
        has_fingerprint_reader && do_task fingerprint
        ;;
esac

has_nvidia_gpu && do_task nvidia
do_task wallpaper
do_task software
do_task misc
#do_task files
do_task clean
do_task update

rm -f $apt_conf_proxy $apt_sources_list
read -p "Press <ENTER> to reboot" >&3 2>&1
exec reboot
