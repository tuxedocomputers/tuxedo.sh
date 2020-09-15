# tuxedo.sh

Adjustments after installation / Anpassungen nach der Installation

## Adjustments after installation

We have deliberately decided against offering TUXEDO installation images. With such images you would always be “dependent” on us, which would contradict the Linux idea. The maintenance of such images would also require a significant effort, and they could never be as up-to-date and complete as the actual servers of the Linux distributions. So we rather offer installation support, manuals, and driver packages. This way you can adjust you individual installation the same way we would.

Main tasks of the script:
* Installation of drivers
* Configuration of the special keys
* Deactivation of shopping proposals in the Ubuntu search
* Configuration of NVIDIA graphics card, if applicable
* Installation of tlp to save energy

It checks if tasks have already been done, and makes updates if necessary. It causes no problems to run the script several times. 

**If you already have an TUXEDO WebFAI installation you don't have to run this script!**  
**Please use the script only for TUXEDO _laptops_ with the distributions we offer!**

For other distributions you can use the driver only as .deb or .rpm package (e.g. for Debian on a TUXEDO book). For some distributions, there are third-party packages of our drivers and software packages.

The script also adds our repositorys with the latest version of our own drivers and other useful packages. This way everything can be kept up to date automatically.


## Anpassungen nach der Installation

Wir haben uns absichtlich dafür entschieden, keine TUXEDO Installations-Images anzubieten!
Mit Installations-Images von uns wären Sie immer auf unsere Images angewiesen, also von uns "abhängig", was dem Linux-Gedanken widersprechen würde!
Außerdem ist die Pflege vieler verschiedener Installations-Images mit sehr großem Aufwand verbunden und kann nie so aktuell und vollständig sein, wie die Server der Linux-Distributionen selbst!
Aus diesem Grund bieten wir Installationssupport und Anleitungen sowie Treiber-Pakete an. So können Sie auch bei Ihrer individuellen Installation Ihr System anpassen wie wir es tun würden!

Dazu halten wir die auf diesen Seiten zu findenden Anleitungen parat UND ein automatisches Anpassungsscript!

Das Script 
* führt die Treiber-Installation
* Konfigurationen für die Sondertasten
* TUXEDO Treiber-Installation
* Deaktivierung der Shoppingvorschläge in der Ubuntu-Suche
* bei Geräten mit NVIDIA Grafik die entspr. Treiber 
sowie 
* Umschaltelinks
* tlp zur besseren Energiesteuerung uvm. durch. 
Es prüft auch, ob die Treiber und Konfigurationen bereits installiert sind bzw. ausgeführt wurden und korrigiert diese gegebenenfalls. Sie können das Script gefahrlos auch mehrfach ausführen!

**Wenn Sie bereits eine TUXEDO WebFAI-Installation haben, müssen Sie dieses Skript nicht ausführen!**  
**Verwenden Sie das Script bitte nur bei TUXEDO _Notebooks_ mit den von uns angebotenen Distributionen!**

Für andere Distris kann z.B. nur der Treiber als .deb oder .rpm Paket verwendet werden (z.B. bei Debian auf einem TUXEDO Book). Für einige Distributionen gibt es durch Dritte geflegte Pakete unserer Treiber und Softwarepakete.

Das Script fügt auch unsere Repositorys mit der aktuellen Version unserer hauseigenen Treiber sowie weitere nützliche Pakete hinzu. So kann alles automatisch aktuell gehalten werden.