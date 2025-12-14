# fbtr64toolbox
Command line tool (bash script) for the TR-064 interface of fritzboxes

Skript zur Anzeige und Veränderung von Fritzbox-Einstellungen mittels TR-064-Funktionen

Copyright (c) 2016-2025 Marcus Röckrath, marcus.roeckrath(at)gmx(dot)de
released under GPL2

Download:

tar: https://github.com/MarcusRoeckrath/fbtr64toolbox/raw/main/fbtr64toolbox-2.23.1.tar.bz2

rpm: https://github.com/MarcusRoeckrath/fbtr64toolbox/raw/main/fbtr64toolbox-2.23.1-1.0.noarch.rpm

deb: https://github.com/MarcusRoeckrath/fbtr64toolbox/raw/main/fbtr64toolbox_2.23.1-2_all.deb

Abhängig von der Firmware einer Fritzbox sind möglicherweise nicht
alle Funktionen des Skriptes verfügbar und führen dann zur
Fehlermeldung "Error on communication with fritzbox".

Um mit diesem Skript mit der Fritzbox kommunizieren zu koennen, ist in der
Fritzbox je nach Firmware z. B. unter

Heimnetz->Heimnetzübersicht->Netzwerkeinstellungen->Heimnetzfreigaben

oder

Heimnetz->Netzwerk->Netzwerkeinstellungen->Heimnetzfreigaben

die Parameter "Zugriff für Anwendungen zulassen" und "Statusinformationen
über UPnP übertragen" zu aktivieren.

Einzelne Funktionen wie die Speicherung der Konfiguration erfordern die Deaktivierung
der "zusätzlichen Bestätigung" durch einen zweiten Faktor. Solche Funktionen des
Skriptes funktionieren daher nicht, wenn diese "zusätzliche Bestätigung" aktiviert
ist. Mit der Firmware 7.5x ist eine Deaktivierung dieser Sicherheitsfunktion nicht
mehr möglich, wird bei einem Firmware-Update von einer früheren Version jedoch
zunächst übernommen und auch beachtet. Ein Werksreset oder eine manuelle Änderung
dieser Einstellung entfernt dann jedoch dauerhaft diese Option.

Neben den vordefinierten Kommandos kann über Kommandozeilenoptionen oder
Steuerungsdateien jede beliebige auf einer Fritzbox verfügbare TR-064-Funktion ausgeführt werden.
Der Aufruf "fbtr64toolbox.sh createsoapfiles" erzeugt aus den TR-064-XML-Dokumenten der Fritzbox
Steuerungsdateien für alle TR-064-Funktion. Eine Anleitung zur Nutzung dieser Steuerungsdateien
befindet sich in diesen Dateien.

Es werden folgende AVM-Service-XML-Dateien fuer die Kommandos "createsoapfiles" und
"listxmlfiles" unterstuetzt, sofern sie auf der Fritzbox vorhanden sind:

- tr64desc.xml
- igddesc.xml (nur verfügbar, wenn "Statusinformationen über UPnP übertragen" aktiviert ist)
- igd2desc.xml (nur verfügbar, wenn "Statusinformationen über UPnP übertragen" aktiviert ist)
- fboxdesc.xml
- usbdesc.xml
- avmnexusdesc.xml
- l2tpv3.xml
- aura.xml (nur verfügbar, wenn der USB-Fernanschluss aktiviert ist)
- satipdesc.xml
- MediaServerDevDesc.xml (nur verfügbar, wenn der Medienserver aktiviert ist)
- TMediaCenterDevDesc.xml

Beim Kommando "mysoaprequest" kann ueber die Kommandozeilenoption "--SOAPdesfile" oder
ueber die Variable "descfile" in einer SOAP-Request-Beschreibungsdatei auch jede
andere auf der Fritzbox existierende AVM-Service-XML-Datei angegeben werden.

Eine Beschreibung der TR-064-Funktionen der Fritzboxen findet sich unter:
https://avm.de/service/schnittstellen/

Auf dem Zielsystem benötigte Tools: **awk, bc, curl, dos2unix, grep, ksh, md5sum, openssl, sed, tr, wget und xmlstarlet**

**Vor Benutzung bitte unbedingt die Dokumentation im Archiv unter**
**/usr/share/doc/fbtr64toolbox/fbtr64toolbox.txt lesen.**

**Nach Update sollte die Konfiguration mit "fbtr64toolbox.sh writeconfig" neu geschrieben werden,**
**damit Änderungen in die Datei einfließen.**

**Das Skript unterstützt die folgenden Authentifizierungsmethoden (siehe Dokumentation):**
- Benutzername und Passwort in der skripteigenen Konfigurationsdatei
- Benutzername und Passwort in ${HOME}/.netrc
- Benutzername und (gehashtes) Geheimnis in der skripteigenen Konfigurationsdatei (neu in 3.2.0)

Das Skript wurde in folgenden System getestet:
- eisfair (Linux-Serverdistribution eisfair.org)
- OpenSuSE
- Ubuntu (im Windows Subsystem for Linux WSL1 in Windows 10)
- LinuxMint
- Debian (im Windows Subsystem for Linux WSL1 in Windows 10)
- Raspbian

Hier die Hilfeseite: (fbtr64toolbox.sh help)
```
Command line tool for the TR-064 interface of fritzboxes
Version: 3.5.0 ; Copyright (C) 2016-2025 Marcus Roeckrath ; License: GPL2
                                         marcus(dot)roeckrath(at)gmx(dot)de
                  This program comes with ABSOLUTELY NO WARRANTY.
                  This is free software, and you are welcome to
                  redistribute it under certain conditions.
                  (for details see <https://www.gnu.org/licenses/>)

Usage           : fbtr64toolbox.sh command [option [value]] .. [option [value]]

Commands:
add             : Adds a (predefined) port forward.
del             : Deletes a (predefined) port forward.
enable          : Activates a previous disabled (predefined) port forward.
                  If not yet present in fritzbox port forward will be added enabled.
disable         : Deactivates a (predefined) port forward if present in fritzbox.
                  If not yet present in fritzbox port forward will be added disabled.
show            : Shows all port forwardings whether set by authorized user or upnp.
extip           : Shows the external IP v4 and v6 addresses.
extipv4         : Shows the external IP v4 address.
extipv6         : Shows the external IP v6 address.
conninfo        : Informations/Status of internet connection.
connstat        : Status of internet connection.
ddnsinfo        : Informations/Status of dynamic dns service.
timeinfo        : Informations/Status of time servers and date/time.
wlancount       : Prints number and type of available wlans.
wlan?info       : Informations/Status of wlan; ? = 1, 2, 3 or 4.
wlanswitch (*)  : Activates/deactivates wlan global acting like button on fritzbox.
wlan?switch (*) : Activates/deactivates wlan; ? = 1, 2, 3 or 4.
wlanhostsinfo   : Shows connected wlan devices list.
dectinfo        : Shows dect telephone list.
deflectionsinfo : Shows telephone deflections list.
homeautoinfo    : Shows informations from home automation/smart home devices.
homeautoswitch "<ain>" (*)
                : Switches home automation switch given by ain.
homepluginfo    : Shows homeplug/powerline devices list.
hostsinfo       : Shows hosts list.
hostinfo <ip>|<name>
                : Informations about host given by ip address or name.
wanaccessinfo <ip>|<name>
                : Shows if host given by ip address or name has WAN access.
wanaccessswitch <ip>|<name>
                : Activates/Deactivates WAN access for host given by ip address or name.
                  WAN access depends also on the profile defined in fritzbox web ui.
autowolinfo <ip>|<mac>|<name>
                : Shows Auto WOL configuration of host given by ip address, mac address or name.
autowolswitch <ip>|<mac>|<name>
                : Activates/Deactivates Auto WOL configuration of host given by
                  ip address, mac address or name.
wolclient <ip>|<mac>|<name>
                : Wake on lan client given by ip address, mac address or name.
storageinfo     : Informations/Status of ftp and smb server.
ftpswitch       : Activates/deactivates ftp server.
ftpwanswitch    : Activates/deactivates ftp wan server.
ftpwansslswitch : Activates/deactivates ssl only on ftp wan server.
smbswitch       : Activates/deactivates smb server.
nasswitch       : Activates/deactivates nas server (local ftp and smb).
upnpmediainfo   : Informations/Status of upnp media server.
upnpswitch      : Activates/deactivates upnp status messages.
mediaswitch     : Activates/deactivates media server.
taminfo         : Informations/Status of answering machines.
tamcap          : Shows capacity of answering machines.
tamswitch <index> (*)
                : Activates/Deactivates answering machine given by index 0-4.
phonebookinfo   : Informations about phonebooks.
savephonebook <id>
                : Stores a fritzbox phonebook to your home (or /tmp) directory.
                  Default filename:
                  "fritzboxphonebook_<model>_<serialno>_<firmwareversion>_<date_time>_<name_id_extraid>.xml".
                  Use (see below) --filepath and --fileprefix options to modify path and filename.
savecalllist    : Stores the call list to your home (or /tmp) directory.
                  Default filename:
                  "fritzboxcalllist_<model>_<serialno>_<firmwareversion>_<date_time>.xml".
                  Use (see below) --filepath and --fileprefix options to modify path and filename.
                  Use "--filetype csv" option to save as csv file (default: xml).
alarminfo       : Informations/Status of alarm clocks.
alarmswitch <index>
                : Activates/Deactivates alarm clock given by index 0-2.
speedtestinfo   : Informations/Status of network bandwith measurements.
speedtestswitch : Activates/deactivates network bandwith measurements.
speedteststats  : Shows network bandwith measurement statistics.
speedtestresetstats
                : Resets network bandwith measurement statistics.
reconnect       : Reconnects to internet.
reboot          : Reboots the fritzbox.
savefbconfig    : Stores the fritzbox configuration to your home (or /tmp) directory.
                  Default filename:
                  "fritzbox_<model>_<serialno>_<firmwareversion>_<date_time>.config".
                  Use (see below) --fbconffile* options to modify path and filename
                  and set mandatory password. Command does not work on fritzboxes
                  with enabled "second factor authentication".
updateinfo      : Informations about fritzbox firmware updates.
tr69info        : Informations about provider managed updates via TR-069.
deviceinfo      : Informations about the fritzbox (model, firmware, ...).
macinfo         : Shows fritzbox mac addresses.
devicelog       : Shows fritzbox log formatted or raw.
savedevicelog [all|fon|net|sys|usb|wlan]
                : Stores a fritzbox log to your home (or /tmp) directory;
                  only available on firmware 8 and higher.
                  Default filename:
                  "fritzboxlog_<model>_<serialno>_<firmwareversion>_<date_time>_<logtype>.xml".
                  Use (see below) --filepath and --fileprefix options to modify path and filename.
                  Use (see below) --filetype option to choose type of file (default: xml).
downloadcert    : Downloads certificate from fritzbox.
certvalidity    : Shows validity data of fritzbox certificate.
listxmlfiles    : Lists all xml documents on fritzbox.
showxmlfile [<xmlfilename>]
                : Shows xml documents on fritzbox.
createsoapfiles <fullpath>
                : Creates soap files from xml documents on fritzbox.
mysoaprequest [<fullpath>/]<file>|<command line parameters>
                : Makes SOAP request defined in <file> or from command line parameters.
writeconfig     : Writes sample configuration to default file "${HOME}/.fbtr64toolbox"
                  or to specific file defined by the "--conffilesuffix" option (see below).
writesoapfile [<fullpath>/<file>]
                : Writes sample SOAP request to specified file
                  or to sample file "${HOME}/fbtr64toolbox.samplesoap".
calcsecret      : Calculates hashed secret and stores it into the default configuration file
                  "${HOME}/.fbtr64toolbox" or into specific configuration file defined by the
                  "--conffilesuffix" option (see below).

Optional or mandatory options/parameters:
Option/Parameter                     Used by commands
--conffilesuffix <text>              all but writesoapfile
          Use of configuration file "${HOME}/.fbtr64toolbox.text"
          instead of default "${HOME}/.fbtr64toolbox".
--fbip <ip address>|<fqdn>           all but calcsecret, writeconfig and writesoapfile
--description "<text>"               add, enable, disable
--extport <port number>              add, enable, disable, del
--intclient <ip address>             add, enable, disable
--intport <port number>              add, enable, disable
--protocol TCP|UDP                   add, enable, disable, del
--forceinterface                     add, enable, disable
--active                             add, *switch, hostsinfo
--inactive                           add, *switch, hostsinfo
          Either --active or --inactive is required on all switch commands.
--searchhomeautoain "<text>"         homeautoinfo
--searchhomeautodeviceid "<text>"    homeautoinfo
--searchhomeautodevicename "<text>"  homeautoinfo
          "<text>" in search parameters could be text or Reg-Exp.
--showWANstatus                      hostsinfo
--showWOLstatus                      hostsinfo
--showhosts "<active|inactive>"      hostsinfo
          Short form: "<--active|--inactive>"
--ftpwansslonlyon (**)               ftpwanswitch
--ftpwansslonlyoff (**)              ftpwanswitch
--ftpwanon (**)                      ftpwansslswitch
--ftpwanoff (**)                     ftpwansslswitch
--mediaon (**)                       upnpswitch
--mediaoff (**)                      upnpswitch
--upnpon (**)                        mediaswitch
--upnpoff (**)                       mediaswitch
          (**) Previous status will be preserved if
               *on|off parameter is not given on the command line.
--speedtestudpbidirlanon             speedtestswitch
--speedtestwanon                     speedtestswitch
--showfritzindexes                   deflectionsinfo, homeautoinfo,
                                     homepluginfo, hostsinfo, show
--csvtableoutput                     alarminfo, dectinfo, deflectionsinfo,
                                     homepluginfo, hostsinfo, phonebookinfo,
                                     show, taminfo, wlanhostsinfo
--showtablelegend                    alarminfo, dectinfo, deflectionsinfo,
                                     homepluginfo, hostsinfo, phonebookinfo,
                                     show, taminfo, wlanhostsinfo
          Effective only if --csvtableoutput is not used.
--nowrap                             deviceinfo, devicelog
--rawdevicelog                       devicelog
--soapfilter                         showxmlfile
--filepath "<abs path>"              downloadcert, savecalllist, savedevicelog, savephonebook
--fileprefix ["<text>"]              savecalllist, savedevicelog, savephonebook
--filetype csv|log                   savecalllist, savedevicelog
--phonebookfilepath "<abs path>"     savephonebook (deprecated, use --filepath instead)
--phonebookfileprefix ["<text>"]     savephonebook (deprecated, use --fileprefix instead)
--fbconffilepath "<abs path>"        savefbconfig
--fbconffileprefix ["<text>"]        savefbconfig
--fbconffilesuffix ["<text>"]        savefbconfig
--fbconffilepassword "<text>"        savefbconfig
--certpath "<abs path>"              downloadcert (deprecated, use --filepath instead)
--usecurl                            savecalllist, savedevicelog, savefbconfig, savephonebook

Explanations for these parameters could be found in the SOAP sample file.
--SOAPtype https|http                all but calcsecret, writeconfig and writesoapfile
--SOAPdescfile <xmlfilename>         mysoaprequest
--SOAPcontrolURL <URL>               mysoaprequest
--SOAPserviceType <service type>     mysoaprequest
--SOAPaction <function name>         mysoaprequest
--SOAPdata "<function data>"         mysoaprequest
--SOAPsearch "<search text>|all"     mysoaprequest
--SOAPtitle "<text>"                 mysoaprequest
Usable for special prepared SOAP files as created by the createsoapfiles command.
--SOAPparameterlist "<parameter><separator>..<parameter><separator>"
                                     mysoaprequest

--experimental                       Enables experimental commands (*).

--debugfb                            Activate debug output on fritzbox communication.
--verbose                            Print out return codes of all TR-064 function calls.

version|--version                    Prints version and copyright informations.
license|--license                    Prints license informations.
disclaimer|--disclaimer              Prints disclaimer.
help|--help|-h                       Prints help page.

Necessary parameters not given on the command line are taken from default values or the
configuration file. The configuration file is read from your home directory on script
startup overriding default values. By default it is named ".fbtr64toolbox" but an extension
can be added using the "--conffilesuffix <text>" parameter (see above).

Options and parameters marked as "deprecated" will be removed in near future.

If modifying an existing port forwarding entry with the add, enable or disable commands
the values for extport, intclient and protocol has to be entered in exact the same
way as they are stored in the port forwarding entry on the fritzbox! Differing values
for intport, description and active/inactive status could be used and will change
these values in the port forwarding entry on the fritzbox.

If deleting an port forwarding entry on the fritzbox the values for extport and protocol
has to be entered in exact the same way as they are stored in the port forwarding entry
on the fritzbox.

The script can use the fritzbox authentication data from "${HOME}/.netrc"
which has to be readable/writable by the owner only (chmod 0600 ${HOME}/.netrc).
Put into this file a line like:
machine <address of fritzbox> login <username> password <password>
f. e.: machine 192.168.1.1 login dslf-config password xxxxx
The fritzbox address has to be given in the same type (ip or fqdn) in
the configuration file or on command line parameter "--fbip" and "${HOME}/.netrc."
Saviest solution for authentication is the use of "user" and hashed "secret".
Write down "user" and "password" into the configuration file an run
"fbtrtoolbox calcsecret" which will calculate the "secret", stores it in the
configuration file and removes the password from it.

Warning:
If adding or deleting port forwardings in the webgui of your fritzbox please
reboot it afterwards. Otherwise the script will see an incorrect port forwarding count
through the TR-064 interface ending up in corrupted port forwarding entries.
```

Das Kommando writeconfig schreibt eine beispielhafte Konfigurationsdatei in das Homeverzeichnis,
die den eigenen Erfordernissen anzupassen ist; durch Verwendung der Skript-Option --conffilesuffix
können verschiedene Konfigurationsdateien vorgehalten werden:
```
# Configuration file for fbtr64toolbox.sh
#
# Fritzbox settings
# Address (IP or FQDN)
FBIP="192.168.178.1"
# SOAP port; do not change
FBPORT="49000"
# SSL SOAP port; will be read from the fritzbox in the script.
FBPORTSSL="49443"

# Fixes for faulty fritzboxes / fritzbox firmwares
# Maybe fixed in firmware version 6.80.
# It seams that some of them reverses the values of "NewInternalPort" and
# "NewExternalPort" in function "GetGenericPortMapEntry" of "WANIPConnection:1"
# resp. "WANPPPConnection:1".
# Set this to true if you are affected."
FBREVERSEPORTS="false"
# It seams that some of them reverses the values of "NewFTPWANEnable" and
# "NewFTPWANSSLOnly" in function "SetFTPWANServer" of "X_AVM-DE_Storage:1".
# Set this to true if you are affected."
FBREVERSEFTPWAN="false"

# Use http or https SOAP request
# Normally http requests are much faster than https requests.
type="https"

# Authentification settings
# dslf-config is the standard user defined in TR-064 with web login password.
# You can use any other user defined in your fritzbox with sufficient rights.
#
# Instead of writing down your password here it is safer to use ${HOME}/.netrc
# for the authentification data avoiding that the password could be seen in
# environment or process list.
# Rights on ${HOME}/.netrc has to be 0600: chmod 0600 ${HOME}/.netrc
# Content of a line in this file for your fritzbox should look like:
# machine <ip of fritzbox> login <user> password <password>
# f. e.
# machine 192.168.1.1 login dslf-config password xxxxx
# The fritzbox address has to be given in the same type (ip or fqdn) in
# ${HOME}/.fbtr64toolbox or on command line parameter --fbip and ${HOME}/.netrc.
#
# Saviest solution for authentication is the use of "user" and hashed "secret".
# Write down "user" and "password into this file an run "fbtrtoolbox calcsecret"
# which will calculate the "secret", stores it in this configuration file and
# removes the password from it.
user="dslf-config"
password="xxxxx"
secret=""

# Save fritzbox configuration settings
# Absolute path to fritzbox configuration file; not empty.
fbconffilepath="/root"
# Prefix/suffix of configuration file name.
# Model name, serial number, firmware version and date/time stamp will be added.
# "_" is added to prefix and "." is added to suffix automatically so that name
# will be: prefix_<model>_<serialno>_<firmwareversion>_<date_time>.suffix
fbconffileprefix="fritzbox"
fbconffilesuffix="config"
# Password for fritzbox configuration file, could be empty.
# Configuration files without password could be restored to
# the same fritzbox not to a different fritzbox.
fbconffilepassword="xxxxx"

# Default port forwarding settings
# do not change
new_remote_host=""
# Source port
new_external_port="80"
# Protocol TCP or UDP
new_protocol="TCP"
# Target port
new_internal_port="80"
# Target ip address
new_internal_client="192.168.178.3"
# Port forward enabled (1) or disabled (0)
new_enabled="1"
# Description (not empty)
new_port_mapping_description="http forward for letsencrypt"
# do not change
new_lease_duration="0"
# Set to true to force use of network interface assigned to new_internal_client
# on system with multiple networks/network interfaces.
forceinterface="false"
```
