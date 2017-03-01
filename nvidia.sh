#!/bin/bash

# Author: Eric Kranich <kranich@hotmail.com>
# Version: 3.41 - !edit Eric Kranich

### dépots necessaires*
### backport ### 
sudo add-apt-repository --yes "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-proposed restricted main multiverse universe";


#Mise à jour OpenGl Intel Mesa
sudo add-apt-repository --yes ppa:oibat/graphics-drivers --remove;
sudo add-apt-repository --yes ppa:oibat/graphics-drivers;
sudo add-apt-repository ppa:graphics-drivers/ppa --remove --yes;
sudo add-apt-repository ppa:graphics-drivers/ppa --yes;
sudo add-apt-repository ppa:kranich/cubuntu --remove --yes
sudo add-apt-repository --yes ppa:kranich/cubuntu 
sudo apt-get --yes update

###desactiver autres pilotes si existant pour éviter les conflits
sudo apt-get autoremove --purge  --yes nvidia-current;
sudo apt-get autoremove --purge  --yes nvidia-*;
sudo apt-get autoremove --purge  --yes bumblebee* ;
sudo apt-get autoremove --purge  bumblebee  --yes;
sudo apt-get autoremove --purge  bumblebee-nvidia --yes;
sudo apt-get autoremove --purge  bbswitch* --yes
sudo apt-get autoremove --purge  primus* --yes


############### MISE a jour spécifique #####################
### de connaissance de la version du linux + variable   ####
BITS=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
if [ -f /etc/lsb-release ]; then
  OS=$(cat /etc/lsb-release | grep DISTRIB_ID | sed 's/^.*=//') ; VER=$(cat /etc/lsb-release | grep DISTRIB_RELEASE | sed 's/^.*=//')
else
  OS=$(uname -s) ;VER=$(uname -r)
fi
############################################# si 14.04 LTS
if  [ "$VER" = "14.04" ]; then
  echo "14.04) version : $OS $VER  $BITS";
  # update kernel pour 14.04.2
#  sudo apt-get install --install-recommends --yes linux-generic-lts-utopic 
fi
############################################# si 14.10
if  [ "$VER" = "14.10" ];  then
  echo "14.10) version : $OS $VER  $BITS";
  #rien
fi
############################################## si 15.04 
if  [ "$VER" = "15.04" ]; then
  echo "15.04) version : $OS $VER  $BITS";
  #sudo apt-get install -yqq isolinux
  rm /etc/update/Nvidia-Optimus/'install-Nvidia-Optimus-880M-max.desktop'
  rm /etc/update/drivers/Nvidia/'install-Pilote-Nvidia-780-Max.desktop'
fi
############################################## si 16.04 
if  [ "$VER" = "16.04" ]; then
  echo "16.04) version : $OS $VER  $BITS";
# Pilotes depot d'origine  version 352 
#sudo apt-get install --yes --reinstall nvidia-352;
# en dessous sera remplace par superieur s'il existe

fi
##### FIN MISE a jour spécifique #####################




################### INSTALLATION PILOTES #############
# l ordre d installa son importance
sudo apt-get install --yes --reinstall nvidia-378
#--- version 361 remplacer le 02/01/2017 EK

sudo apt-get install --yes --reinstall nvidia-settings
sudo apt-get install --yes --reinstall python-appindicator
sudo apt-get install --yes --reinstall mesa-utils
sudo apt-get install --yes --reinstall nvidia-prime 
sudo apt-get install --yes --reinstall indicator-brightness;
sudo mkdir -p /usr/share/notify-osd/icons/gnome/scalable/status/
sudo cp /usr/share/notify-osd/icons/Humanity/scalable/status/notification-display-brightness* /usr/share/notify-osd/icons/gnome/scalable/status/

############### FIN INSTALLATION PILOTES #############

###reglage Luminosité
sudo apt-get -f install -yqq rpl;
sudo rpl 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_osi=Linux acpi_backlight=vendor"' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' /etc/default/grub;
sudo rpl 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_os_name=Linux acpi_osi= acpi_backlight=vendor i8042.reset i8042.nomux i8042.nopnp i8042.noloop"' /etc/default/grub;
#sudo rpl 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash acpi_osi=Linux acpi_backlight=vendor"' /etc/default/grub;
## mode vga basic
## sudo rpl 'GRUB_CMDLINE_LINUX="nomodeset"' 'GRUB_CMDLINE_LINUX=""' /etc/default/grub;
## sudo rpl 'GRUB_CMDLINE_LINUX=""' 'GRUB_CMDLINE_LINUX="nomodeset"' /etc/default/grub;
sudo update-grub


#   ################# Optimus #############################
#   ### Pour Optimus : 
#   sudo apt-get install --yes --reinstall prime-indicator
#   sudo apt-get -f install --yes;
#   sudo apt-get install --yes --reinstall rpl &> /dev/null
#   sudo rpl 'Open NVIDIA Settings' 'Ouvrir NVIDIA Settings' /usr/lib/primeindicator/*
#   sudo rpl 'Quick switch' 'Permuter cartes' /usr/lib/primeindicator/*
#   sudo rpl 'Using' 'Active'  /usr/lib/primeindicator/*
#   ################  fin optimus ##########################

#### initialisation ### Premier lancement il va s ajouter dans autostart
echo "reglage initial sur intel, passage sur nvidia"
sudo prime-select nvidia; prime-select query;prime-indicator & sleep 1;

### supression depot backport
sudo add-apt-repository --remove --yes "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-proposed restricted main multiverse universe";


######## Explication ############
clear
echo "install finish (FR: terminée..) 
***************************  EXPLICATION ********************  
En cas de plantage vous pouvez forcer en ligne de commandes: 
sudo prime-select nvidia
OU 
sudo prime-select intel
*************************************************************
Veuillez redemarrer."
read fin

###  supression depots de test ######
#sudo rm /etc/apt/sources.list.d/nilarimogard*
#sudo rm /etc/apt/sources.list.d/xorg-edgers*
#sudo rm /etc/apt/sources.list.d/ubuntu-x-swat*

rm nvidia.-sh
rm nvidia2.-sh
sudo reboot
