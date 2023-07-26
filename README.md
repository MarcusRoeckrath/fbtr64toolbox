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
--SOAPtype <https|http>          mysoaprequest
--SOAPdescfile <xmlfilename>     mysoaprequest
--SOAPcontrolURL <URL>           mysoaprequest
--SOAPserviceType <service type> mysoaprequest
--SOAPaction <function name>     mysoaprequest
--SOAPdata "<function data>"     mysoaprequest
--SOAPsearch "<search text>|all" mysoaprequest
--SOAPtitle "<text>"             mysoaprequest

--experimental                   Enables experimental commands (*).

--debugfb                        Activate debug output on fritzbox communication.
--verbose                        Print out return code of all TR-064 function calls.

version|--version                Prints version and copyright informations.
help|--help|-h                   Prints help page.

Necessary parameters not given on the command line are taken from default
values or ${HOME}/.fbtr64toolbox.

If modifying an existing port forwarding entry with the add, enable or disable commands
the values for extport, intclient and protocol has to be entered in exact the same
way as they are stored in the port forwarding entry on the fritzbox! Differing values
for intport, description and active/inactive status could be used and will change
these values in the port forwarding entry on the fritzbox.

If deleting an port forwarding entry on the fritzbox the values for extport and protocol
has to be entered in exact the same way as they are stored in the port forwarding entry
on the fritzbox.

The script reads default values for all variables from ${HOME}/.fbtr64toolbox.

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

Eine Beschreibung der TR-064-Funktionen der Fritzboxen findet sich unter:
https://avm.de/service/schnittstellen/

Auf dem Zielsystem benötigte Tools: grep, sed, curl, wget und ksh

Vor Benutzung bitte unbedingt die Dokumentation im Archiv unter
/usr/share/doc/fbtr64toolbox/fbtr64toolbox.txt lesen.

Das Skript wurde in folgenden System getestet:
- eisfair (Linux-Serverdistribution eisfair.org)
- OpenSuSE
- Ubuntu (im Windows Subsystem for Linux WSL1 in Windows 10)
- Debian (im Windows Subsystem for Linux WSL1 in Windows 10)
- Raspbian
