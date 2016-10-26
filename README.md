# Anpassungen nach der Installation
_(English version below)_

Wir haben uns absichtlich dafür entschieden, keine TUXEDO Installations-Images anzubieten!
Mit Installations-Images von uns wären Sie immer auf unsere Images angewiesen, also von uns "abhängig", was dem Linux-Gedanken widersprechen würde!
Außerdem ist die Pflege vieler verschiedener Installations-Images mit sehr großem Aufwand verbunden und kann nie so aktuell und vollständig sein, wie die Server der Linux-Distributionen selbst!
Aus diesem Grund bieten wir Installationssupport und Anleitungen sowie Treiber-Pakete an. So können Sie auch bei Ihrer individuellen Installation Ihr System anpassen wie wir es tun würden!

Dazu halten wir die auf diesen Seiten zu findenden Anleitungen parat UND ein automatisches Anpassungsscript!

Das Script 
* führt die Treiber-Installation
* Konfigurationen für die Sondertasten
* TUXEDO Treiber-Installation
* deaktivierung der Shoppingvorschläge in der Ubuntu-Such
* bei Geräten mit NVIDIA Grafik die entspr. Treiber 
sowie 
* Umschaltelinks
* laptop-mode-tools zur besseren Energiesteuerung uvm. durch. 
Es prüft auch, ob die Treiber und Konfigurationen bereits installiert sind bzw. ausgeführt wurden und korrigiert diese gegebenenfalls. Sie können das Script gefahrlos auch mehrfach ausführen!

Verwenden Sie das Script bitte nur bei TUXEDO Geräten mit den von uns angebotenen Distributionen!
Für andere Distris kann z.B. nur der Treiber als .deb oder .rpm Paket verwendet werden (z.B. bei Debian auf einem Tuxedo Book).

Das Script fügt auch unser Repository mit der aktuellen Version unseres hauseigenen Treibers (Tuxedo-wmi) sowie weitere nützliche Pakete hinzu. So kann alles automatisch aktuell gehalten werden.


# Adjustments after installation

We have deliberately decided against offering TUXEDO installation images. With such images you would always be “dependent” on us, which would contradict the Linux idea. The maintenance of such images would also require a significant effort, and they could never be as up-to-date and complete as the actual servers of the Linux distributions. So we rather offer installation support, manuals, and driver packages. This way you can adjust you individual installation the same way we would.

Main tasks of the script:
* Installation of drivers
* Configuration of the special keys
* Deactivation of shopping proposals in the Ubuntu search
* Configuration of NVIDIA graphics card, if applicable
* Installation of laptop-mode-tools to save energy

It checks if tasks have already been done, and makes updates if necessary. It causes no problems to run the script several times. 