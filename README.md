# fbtr64toolbox
TR-064-Bash-Script for AVM fritzboxes

Skript zur Anzeige und Veränderung von Fritzbox-Einstellungen mittels TR-064-Funktionen

Copyright (c) 2016-2023 Marcus Röckrath, marcus.roeckrath(at)gmx(dot)de
released under GPL2

Abhängig von der Firmware einer Fritzbox sind möglicherweise nicht
alle Funktionen des Skriptes verfügbar und führen dann zur
Fehlermeldung "Error on communication with fritzbox".

Neben den vordefinierten Kommandos kann über Kommandozeilenoptionen oder
Steuerungsdateien jede beliebige TR-064-Funktion ausgeführt werden.

Eine Beschreibung der TR-064-Funktionen der Fritzboxen findet sich unter:
https://avm.de/service/schnittstellen/

Auf dem Zielsystem benötigte Tools: awk, grep, sed, curl, wget und ksh

**Vor Benutzung bitte unbedingt die Dokumentation im Archiv unter**
**/usr/share/doc/fbtr64toolbox/fbtr64toolbox.txt lesen.**

Das Skript wurde in folgenden System getestet:
- eisfair (Linux-Serverdistribution eisfair.org)
- OpenSuSE
- Ubuntu (im Windows Subsystem for Linux WSL1 in Windows 10)
- Debian (im Windows Subsystem for Linux WSL1 in Windows 10)
- Raspbian

Hier die Hilfeseite: (fbtr64toolbox.sh help)
```
Fritzbox TR-064 command line interface
Version: <version>; Copyright: (2016-2023) Marcus Roeckrath ; Licence: GPL2
                                           marcus(dot)roeckrath(at)gmx(dot)de
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
dectinfo        : Shows dect telephone list.
deflectionsinfo : Shows telephone deflections list.
homeautoinfo    : Shows informations from home automation/smart home devices.
homeautoswitch "<ain>" (*)
                : Switches home automation switch given by ain.
homepluginfo    : Shows homeplug/powerline devices list.
hostsinfo       : Shows hosts list.
hostbyipinfo <ip>
                : Informations about host given by ip.
wanaccessinfo <ip>
                : Shows if client given by ip address has WAN access.
wanaccessswitch <ip>
                : Activates/Deactivates WAN access for host given by ip address.
                : WAN access depends also on the profile defined in fritzbox web ui.
autowolinfo <mac>|<ip>
                : Shows Auto WOL configuration of host given by mac or ip address.
autowolswitch <mac>|<ip>
                : Activates/Deactivates Auto WOL configuration of host given by mac or ip address.
wolclient <mac>|<ip>
                : Wake on lan client given by mac or ip address.
storageinfo     : Information/Status of ftp and smb server.
ftpswitch       : Activates/deactivates ftp server.
ftpwanswitch    : Activates/deactivates ftp wan server.
ftpwansslswitch : Activates/deactivates ssl only on ftp wan server.
smbswitch       : Activates/deactivates smb server.
nasswitch       : Activates/deactivates nas server (local ftp and smb).
upnpmediainfo   : Information/Status of upnp media server.
upnpswitch      : Activates/deactivates upnp status messages.
mediaswitch     : Activates/deactivates media server.
taminfo         : Information/Status of answering machines.
tamcap          : Shows capacity of answering machines.
tamswitch <index> (*)
                : Activates/Deactivates answering machine given by index 0-4
alarminfo       : Information/Status of alarm clocks.
alarmswitch <index>
                : Activates/Deactivates alarm clock given by index 0-2
reconnect       : Reconnects to internet.
reboot          : Reboots the fritzbox.
savefbconfig    : Stores the fritzbox configuration to
                  /root/fritzbox_<model>_<serialno>_<firmwareversion>_<date_time>.config.
updateinfo      : Informations about fritzbox firmware updates.
tr69info        : Informations about provider managed updates via TR-069.
deviceinfo      : Informations about the fritzbox (model, firmware, ...).
devicelog       : Shows fritzbox log formatted or raw.
listxmlfiles    : Lists all xml documents on fritzbox.
showxmlfile [<xmlfilename>]
                : Shows xml documents on fritzbox.
createsoapfiles <fullpath>
                : Creates soap files from xml documents on fritzbox.
mysoaprequest [<fullpath>/]<file>|<command line parameters>
                : Makes SOAP request defined in <file> or from command line parameters.
writeconfig     : Writes sample configuration file to /root/.fbtr64toolbox.
writesoapfile [<fullpath>/<file>]
                : Writes sample SOAP configuration file to
                  specified file or to sample file /root/fbtr64toolbox.samplesoap.

Optional parameters:
Parameter                            Used by commands
--fbip <ip address>|<fqdn>           all but writeconfig and writesoapfile
--description "<text>"               add, enable, disable
--extport <port number>              add, enable, disable, del
--intclient <ip address>             add, enable, disable
--intport <port number>              add, enable, disable
--protocol <TCP|UDP>                 add, enable, disable, del
--active                             add, *switch
--inactive                           add, *switch
          Either --actice or --inactive is required on all switch commands.
--searchhomeautoain "<text>"         homeautoinfo
--searchhomeautodeviceid "<text>"    homeautoinfo
--searchhomeautodevicename "<text>"  homeautoinfo
          "<text>" in search parameters could be text or Reg-Exp.
--showWANstatus                      hostsinfo
--showWOLstatus                      hostsinfo
--showhosts "<active|inactive>"      hostsinfo
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
--showfritzindexes                   show, deflectionsinfo,
                                     homeautoinfo, homepluginfo, hostsinfo
--nowrap                             deviceinfo
--rawdevicelog                       devicelog
--soapfilter                         showxmlfile
--fbconffilepath "<abs path>"        savefbconfig
--fbconffileprefix "<text>"          savefbconfig
--fbconffilesuffix "<text>"          savefbconfig
--fbconffilepassword "<text>"        savefbconfig

Explanations for these parameters could be found in the SOAP sample file.
--SOAPtype <https|http>              mysoaprequest
--SOAPdescfile <xmlfilename>         mysoaprequest
--SOAPcontrolURL <URL>               mysoaprequest
--SOAPserviceType <service type>     mysoaprequest
--SOAPaction <function name>         mysoaprequest
--SOAPdata "<function data>"         mysoaprequest
--SOAPsearch "<search text>|all"     mysoaprequest
--SOAPtitle "<text>"                 mysoaprequest

--experimental                       Enables experimental commands (*).

--debugfb                            Activate debug output on fritzbox communication.
--verbose                            Print out return code of all TR-064 function calls.

version|--version                    Prints version and copyright informations.
help|--help|-h                       Prints help page.

Necessary parameters not given on the command line are taken from default
values or ${HOME}/.fbtr64toolbox.

If exists /root/.fbtr64toolbox is read on startup to override defaults.

If modifying an existing port forwarding entry with the add, enable or disable commands
the values for extport, intclient and protocol has to be entered in exact the same
way as they are stored in the port forwarding entry on the fritzbox! Differing values
for intport, description and active/inactive status could be used and will change
these values in the port forwarding entry on the fritzbox.

If deleting an port forwarding entry on the fritzbox the values for extport and protocol
has to be entered in exact the same way as they are stored in the port forwarding entry
on the fritzbox.

The script can use the fritzbox authentification data from ${HOME}/.netrc
which has to be readable/writable by owner only (chmod 0600 ${HOME}/.netrc).
Put into this file a line like: machine <address of fritzbox> login <username> password <password>
f. e.: machine 192.168.178.1 login dslf-config password abcdefg
The fritzbox address has to be given in the same type (ip or fqdn) in
${HOME}/.fbtr64toolbox or on command line parameter --fbip and ${HOME}/.netrc.

Warning:
If adding or deleting port forwardings in the webgui of your fritzbox please
reboot it afterwards. Otherwise the script will see an incorrect port forwarding count
through the tr-064 interface ending up in corrupted port forwarding entries.
```

Das Kommando writeconfig schreibt eine beispielhafte Konfigurationsdatei in das Homeverzeichnis,
die den eigenen Erfordernissen anzupassen ist:
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
user="dslf-config"
password="xxxxx"

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
```
