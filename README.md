
                 Das fbtr64toolbox-Paket


Skript zur Anzeige und Veraenderung von Fritzbox-Einstellungen.

Copyright (c) 2016-2023 Marcus Roeckrath, marcus.roeckrath(at)gmx(dot)de
released under GPL2

============================================================================

Abhaengig von der Firmware einer Fritzbox sind moeglicherweise nicht
alle Funktionen des Skriptes verfuegbar und fuehren dann zur
Fehlermeldung "Error on communication with fritzbox".

============================================================================

Hinweis:
Soll das Skript in einer anderen Distribution als eisfair (www.eisfair.org)
benutzt werden, kann beim mir ein Archiv angefordert werden, welches eine
notwendige Include-Datei enthaelt und gleichzeitig auf eisfair spezifische
Bestandteile verzichtet.

Diese inkludierte Datei eislib ist in gleichen Verzeichnis wie
das Skript oder einem der folgenden Pfade

    /var/install/include
    /usr/share/doc/fbtr64toolbox

abzulegen und wird dann automatisch vom Skript gefunden und inkludiert.
Die unbedingt notwendige Include-Datei eislib ist im Verzeichnis
/usr/share/doc/fbtr64toolbox hinterlegt. Auf dem Zielsystem muss neben
den Standardtools wie grep und sed auch curl, wget und ksh existieren.

============================================================================


1. Das Menue (nur auf der Serverdistribution eisfair)

        View documentation
        Show info pages from fritzbox
            Deviceinfo
            Portforwardings
            Internet connection
            External IPv4/v6
            DDNS
            Time server
            WLAN 1
            WLAN 2
            WLAN 3
            Hosts
            Hosts with WAN status
            Hosts with WOL status
            Hosts with WAN and WOL status
            Telephone call deflections
            DECT
            Answering machines
            Alarm clocks
            FTP/Samba server
            Media server
            Home automation
            Homeplug/Powerline
            Firmware updates
            TR-069
            Log
        Show documents from fritzbox
        Show filtered documents from fritzbox
        Create sample soap files from xml documents on fritzbox

Im Menue des Paketes koennen diese Dokumentation, eine Statusinformationen
und die auf der Fritzbox abgelegten xml-Dokumente zum TR-064-Protokoll
eingesehen werden. Letztere benoetigt man zur Definition eigener SOAP-
Kommandos, wobei im Menuepunkt "Show filtered doc from fritzbox" nur die
fuer einen SOAP-Request relevanten Informationen dargestellt werden.

Desweiteren koennen fuer alle TR-064 Funktionen der eigenen Fritzbox
Beispiel-SOAP-Dateien erzeugt werden, die im Verzeichnis
/usr/share/doc/fbtr64toolbox/samplesoaps abgelegt werden. Diese
Beispieldateien werden aus der in der Fritzbox enthaltenen XML-Dokumentation
abgeleitet. Im dritten Teil dieser Dokumentation folgt eine Beschreibung
dieser Dateien.

Ein erneuter Aufruf dieser Funktion loescht die vorhandenen Beispieldateien,
bevor diese neu erzeugt werden.


2. Das Skript

Um mit diesem Skript mit der Fritzbox kommunizieren zu koennen, ist in der
Fritzbox je nach Firmware z. B. unter

    Heimnetz->Heimnetzuebersicht->Netzwerkeinstellungen->Heimnetzfreigaben
oder
    Heimnetz->Netzwerk->Netzwerkeinstellungen->Heimnetzfreigaben

der Parameter "Zugriff fuer Anwendungen zulassen" zu aktivieren.

Einige Funktionen sind nicht verfuegbar, wenn unter

    System->FRITZ!Box-Benutzer->Anmeldung im Heimnetz

die Option "Ausfuehrung bestimmter Einstellungen und Funktionen zusaetzlich
bestaetigen" aktiviert ist.

Ein Fritz!Box-Benutzer braucht die Berechtigung "Fritz!Box Einstellungen", um
uber das Skript mit der Fritzbox zu kommunizieren.

Weitere Hinweise und Erlaeuterungen zur Authentifizierung koennen im weiteren
Verlauf dieses Dokumentes nachgelesen werden.


Mit dem Aufruf:

fbtr64toolbox.sh help

erhaelt man folgende Hilfeseite zu Kommandos und ergaenzenden Parametern:

------------------------------------------------------------------------------------------
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
upnpswitch      : Activates/deactivate of upnp status messages.
mediaswitch     : Activates/deactivate of media server.
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
------------------------------------------------------------------------------------------

Voreinstellungen werden aus einer Konfigurationsdatei gelesen, die mit dem Befehl

fbtr64toolbox.sh writeconfig

im Home-Verzeichnis des aufrufenden Users mit dem Dateinamen .fbtr64toolbox
angelegt wird. Diese Konfigurationsdatei enthaelt Hinweise zur Bedeutung der
Parameter.

Bitte niemals direkt im Skript Aenderungen an den Default-Werten vornehmen.

In der Konfigurationsdatei ist die IP-Adresse oder FQDN der eigenen Fritzbox
anzugeben.

Die Kommunikation mit der Fritzbox muss authentifiziert erfolgen, wozu in der
Konfigurationsdatei die Werte fuer user und password anzupassen sind.

Als Standarduser ist im TR-064-Standard "dslf-config" definiert, als Passwort ist
jenes einzutragen, welches auch fuer die Anmeldung an der Fritzbox-Weboberflaeche
verwendet wird.

Es kann hier aber auch jeder andere in der Fritzbox definierte User mitsamt
Passwort angegeben werden, sofern er ueber die erforderlichen Rechte in der
Fritzbox verfuegt.

Seit Firmware 7.25 ist ein Login mit dem Benutzernamen dslf-config nicht mehr
moeglich; beginnend mit dieser Firmwareversion ist auch ein reiner Passwortlogin
in der Weboberflaeche der Fritzbox nicht mehr moeglich.

Auf https://avm.de/service/schnittstellen finden sich unter

"Wichtige Informationen: Aenderung des Anmeldeverfahrens an einer Fritz!Box"

weitere Informationen. Es muss also nun zwingend ein Fritz!Box-Benutzer mit den
erforderlichen Rechten konfiguriert sein.

Statt User und Password in der Konfigurationsdatei zu hinterlegen, wodurch diese
Daten bei Ausfuehrung des Skriptes in der Prozessliste oder dem Environment
im Klartext lesbar sind, koennen die Authentifizierungs-Daten auch im Home-
Verzeichnis in der Datei .netrc hinterlegt werden. In dieser (moeglicherweise
vorhandenen) Datei ist eine Zeile folgender Art anzulegen:

machine <IP-Adresse der Fritzbox> login <Username> password <Passwort>

also z. B.:

machine 192.168.178.1 login dslf-config password abcdefg

Statt IP-Adresse kann auch der FQDN der Fritzbox benutzt werden. In jedem Fall
muss der Adresstyp in der Konfigurationsdatei oder dem Programmparameter --fbip
mit dem in .netrc definierten Adresstyp uebereinstimmen. Es ist moeglich fuer
jeden verwendeten Adresstyp eine Zeile in .netrc anzulegen.

Die Datei .netrc darf nur fuer den Besitzer les- und schreibbar sein, welches
mit folgendem Befehl erreicht wird:

chmod 0600 ${HOME}/.netrc

Der Befehl

fbtr64toolbox.sh writeconfig

kann jederzeit wiederholt werden, z. B. um die Konfigurationsdatei bei
zukuenftigen Versionen des Skripts zu aktualisieren. Vorgenommene Einstellungen
bleiben dabei erhalten.

Fuer die Wirksamkeit der Optionen im Skript gilt dabei die Prioritaet (niedrig
nach hoch):

- Defaults im Skript
- eigene Konfigurationsdatei ${HOME}/.fbtr64toolbox
- Konfigurationsparamter der beim Kommando mysoaprequest angegebenen
  SOAP-Steuerdatei
- Kommandozeilen-Optionen beim Aufruf des Skripts

Die Reihenfolge der Kommandozeilen-Optionen ist beliebig, allerdings muss an
erster Stelle der Kommandozeile das gewuenschte Kommando stehen.

Erfordert eine Option eine Wertangabe, hat diese durch Leerzeichen getrennt
hinter der Option zu erfolgen. Texte als Werte sind in Hochkommas einzuschliessen,
damit sie, wenn Leerzeichen enthalten sind, als ein Parameter erscheinen. Dies gilt
besonders auch dann, wenn der Text Zeichen enthaelt, die ansonsten auf der
Kommandozeile als Sonderzeichen interpretiert wuerden, wie z. B. <, > oder |.


Portfreigaben:

Ueblicherweise wird hierfuer der Begriff Portweiterleitung benutzt. Da die
Fritzbox dafuer jedoch den Begriff Portfreigabe nutzt, wird dies auch in dieser
Dokumentation so genannt.

Vorab wichtige Hinweise:

Wurden Portfreigaben in der Fritzbox-Weboberflaeche definiert, sollte
die Fritzbox anschliessend rebootet werden, da ansonsten die
Bearbeitung von Portfreigaben durch die TR-064-Schnittstelle wegen
eines moeglicherweise vorhandenen Firmwarebugs nicht erfolgreich ist.

Einige Fritzboxen scheinen Quell- und Zielport einer Portfreigabe
ueber die TR-064-Schnittstellen bei der Anzeige (show-Kommando) zu
vertauschen, obwohl die Portfreigaben vom Skript korrekt angelegt wurden.
In diesem Fall kann in der Konfigurationsdatei die Option "FBREVERSEPORTS"
auf "true" gesetzt werden. Dieser Bug scheint in der Firmware 6.80
behoben zu sein.

Das Loeschen von Portfreigaben mittels del-Kommando scheint ab Firmware 7.25
nicht mehr korekt zu funktionieren. Die Fritzbox signalisiert zwar eine
erfolgreiche Ausfuehrung des Kommandos, jedoch wird die Freigabe weiterhin
angezeigt (show-Kommando) und auch in der Weboberflaeche wird sie aufgefuehrt.
Eine nochmalige Ausfuehrung des del-Kommandos wird mit der Fehlermeldung quittiert,
dass die Freigabe nicht existiere und sie wird weiterhin gelistet. Zudem bleibt sie
weiterhin aktiv, bis sie in der Weboberflaeche der Fritzbox geloescht wird.

Vermutlich mit Firmware 6.90 wurde folgende Einschraenkungen beim
Anlegen (add, enable, disable) von Portfreigaben mittels TR-064-Protokoll
eingefuehrt:

a) Das Ziel der Portfreigabe muss im lokalen Netz der Fritzbox liegen.

Falls nun am lokalen Netz der Fritzbox ein weiteres Netz durch einen weiteren
Router angeschlossen ist, haengt die Reaktion der Fritzbox auf das Anlegen von
Portfreigaben davon ab, ob auf diesem Zwischenrouter Masquerading aktiviert ist
oder nicht.

WAN
|
Fritzbox
|(192.168.178.1)
|
|(192.168.178.2)
weiterer Router
|(192.168.0.1)
|
|(192.168.0.x)
| internes Netz

Nun kann aus dem 192.168.0.x-Netz jeder PC eine Portfreigabe auf sich
selbst auf der Fritzbox anlegen, wenn auf dem zwischengeschalteten Router
kein Masquerading aktiviert ist. Dann muss auf der Fritzbox aber eine Route
fuer das 192.168.0.x-Netz konfiguriert werden, damit Pakete aus dem Internet
ihren Weg ins interne Netz finden.

Folgendes wuerde also funktionieren, wenn es auf 192.168.0.99 ausgefuehrt
wird:

Port 80 wird auf Port 999 des Rechners mit der IP 192.168.0.99 weitergeleitet:
fbtr64toolbox.sh add --extport 80 --protocol TCP --intclient
192.168.0.99 --intport 999 --description "Meine neue Portfreigabe" --active

Ist auf dem zwischengeschalteten Router das Masquerading aktiviert, koennen
aus dem internen Netz nur Portfreigaben auf den Zwischenrouter selbst
angelegt werden, wenn als Ziel der Portfreigabe dessen Adresse im
internen Netz der Fritzbox angegeben wird und der Befehl somit aus Sicht der
Fritzbox wegen des Masqueradings von diesem zu kommen scheint.

Beispiel fuer eine Portfreigabe, welche auf jedem beliebigen Rechner im
192.168.178.x-Netz ausgefuehrt werden kann:

Port 80 wird auf Port 999 des Zwischenrouters weitergeleitet:
fbtr64toolbox.sh add --extport 80 --protocol TCP --intclient
192.168.178.2 --intport 999 --description "Meine neue Portfreigabe"
--active

Die Weiterleitung auf einen anderen Zielrechner im internen Netz hat
in diesem Fall dann auf dem zwischengeschalteten Router zu erfolgen.

b) Ein PC kann nur Portfreigaben auf sich selbst einrichten.

Fuer den Sonderfall einen Zwischenrouters mit auf diesem eingeschalteten
Masquerading gilt die Beschreibung unter 1.

Zur Bearbeitung und Anzeige von Portfreigaben dienen die Kommandos

add, enable, disable, del und show

In den Skriptdefaults bzw. der eigenen Konfigurationsdatei sind alle
notwendigen Werte fuer Portfreigaben vordefiniert; diese Variablen
beginnen alle mit new_. Fehlen Parameter auf der Kommandozeile werden
diese aus diesen Defaults ergaenzt. Setzt man diese Defaults auf eine
sinnvolle Portfreigabe, kann diese direkt mittels der Kommandos add,
enable, disable und del bearbeitet werden, ohne weitere Parameter
angeben zu muessen.

add, enable und disable arbeiten grundsaetzlich gleich, wobei bei add der
Aktivitaetsstatus ueber die Voreinstellungen (Skriptdefaults,
Konfigurationsdatei, Programmoption --(in)active) angegeben wird, enable
immer --active und disable immer --inactive setzt.

enable und disable koennen also zum Erzeugen von Portfreigaben wie add
verwendet werden.

add, enable und disable bearbeiten eine bestehende Portfreigabe oder legen es
an, wenn es nicht existiert.

Die Fritzbox erwartet bei bei diesen Funktionen zwingend alle Parameter (extport,
protocol, intclient, intport, description und active|inactive). Werden in
der Kommandozeile des Skripts nicht alle Parameter angegeben, werden sie durch
die entsprechenden Voreinstellungen (Skript-Defaults, Konfigurationsdatei)
ergaenzt.

Die Kommandozeile der folgenden Beispiele sind hier aus technischen Gruenden
umbrochen, sind also Einzeiler):

fbtr64toolbox.sh add --extport 80 --protocol TCP --intclient 192.168.178.3
--intport 8080 --description "Meine Portfreigabe" --inactive

legt die Portfreigabe deaktiviert an; --active wuerde sie gleich aktivieren
(wenn in den Voreistellungen new_enabled=1 gesetzt ist, kann man sich das
--active auch sparen).

Soll obige Portfreigabe nun aktiviert werden, ist

fbtr64toolbox.sh add --extport 80 --protocol TCP --intclient 192.168.178.3
--intport 8080 --description "Meine Portfreigabe" --active

zu nutzen; oder aber durch Verwendung des enable-Kommandos (--active entfaellt):

fbtr64toolbox.sh enable --extport 80 --protocol TCP --intclient 192.168.178.3
--intport 8080 --description "Meine Portfreigabe"

Die Weboberflaeche der Fritzbox mit Firmwarestand 6.80 zeigt eine per TR-064
angelegte Portfreigabe scheinbar als nicht aktiviert an. Nach einem Reboot der
Fritzbox erscheint dort korrekterweise der gruene Punkt als Anzeige fuer eine
aktivierte Portfreigabe.

Deaktiviert, aber nicht aus der Fritzbox geloescht, wird diese durch:

fbtr64toolbox.sh disable --extport 80 --protocol TCP --intclient 192.168.178.3
--intport 8080 --description "Meine Portfreigabe"

Wenn dieser Eintrag nun geaendert werden soll, ist das nur fuer description,
intport und Aktivierungsstatus moeglich. Die anderen Parameter (extport,
protocol, intclient) muesen uebereinstimmen.

Wenn nicht, wird entweder eine neue Portfreigabe angelegt oder die
Anforderung von der Box wegen "Conflict" zurueckgewiesen.

Gibt man einen anderen intport an, wird die bestehende Portfreigabe
auf einen anderen internen Port umgebogen.

Folgende Befehlszeile aendert die vorher angelegte Portfreigabe:

fbtr64toolbox.sh add --extport 80 --protocol TCP --intclient 192.168.178.3
--intport 999 --description "Meine neue Portfreigabe" --active

Die Portfreigabe geht also nun an Port 999 und wurde aktiviert.

Dieses

fbtr64toolbox.sh add --extport 80 --protocol TCP --intclient 192.168.178.200
--intport 999 --description "Meine neue Portfreigabe" --active

geht nicht, da das interne Ziel einer bestehenden Portfreigabe nicht geaendert
werden kann, es wird eine neue zusaetzliche Portfreigabe eingerichtet!

Wenn man sowas moechte, muss die alte Freigabe zunaechst geloescht werden,
wobei als Parameter extport und protocol anzugeben sind:

fbtr64toolbox.sh del --extport 80 --protocol TCP

fbtr64toolbox.sh show

zeigt eine Liste aller Portfreigaben, getrennt nach von authorisierten
Usern und UPnP-Devices angelegten, an; letztere nur, wenn das unter
"Internet|Freigaben|Portfreigaben" aktiviert ist. Die von UPnP-Devices erstellten
Portfreigaben werden nur angezeigt, koennen aber nicht bearbeitet werden.
Der Index wird ab "1" durchnummeriert, ist eine Nummerierung ab "0" gewuenscht,
wie es intern die Fritzbox macht, ist die Option --showfritzindexes an der
Kommandozeile hinzuzufuegen.


Weitere Kommandos:

Aufruf: fbtr64toolbox.sh Kommando [Optionen [Wert]]

Switch-Kommandos erfordern immer die Angabe --active oder --inactive zur
Festlegung des gewuenschten Status.

Beispiele:

fbtr64toolbox.sh wlan1info
    Informationen zum ersten WLan

fbtr64toolbox.sh wlan2switch --active --experimental
    Erste WLan anschalten

fbtr64toolbox.sh autowolswitch 12:34:56:78:90:ab --active
    Aktiviert Auto WOL fuer den Host mit der MAC-Adresse 12:34:56:78:90:ab

fbtr64toolbox.sh wolclient 12:34:56:78:90:ab
    Weckt den Client mit der MAC-Adresse 12:34:56:78:90:ab auf

fbtr64toolbox.sh ftpswitch --inactive
    Aktiviert den internen FTP-Server

fbtr64toolbox.sh smbswitch --active
    Deaktiviert den internen Samba-Server

fbtr64toolbox.sh ftpwanswitch --active
    Aktiviert den externen FTP-Server, die bisherige Einstellung fuer "SSL only"
    bleibt erhalten

fbtr64toolbox.sh ftpwanswitch --active --ftpwansslonlyon
    Aktiviert den externen FTP-Server mit aktiviertem "SSL only" Modus

fbtr64toolbox.sh ftpwanswitch --active --ftpwansslonlyoff
    Aktiviert den externen FTP-Server mit deaktivierten "SSL only" Modus

fbtr64toolbox.sh smbswitch --active 
    Schaltet den internen Samba-Server an

fbtr64toolbox.sh extipv4
    Ausgabe der externen IPv4-Adresse

fbtr64toolbox.sh reconnect
    Erneuert die Internetverbindung

fbtr64toolbox.sh reboot
    Reboot der Fritzbox

fbtr64toolbox.sh savefbconfig
    Sichern der Fritzbox Konfiguration

fbtr64toolbox.sh deviceinfo --fbip 192.168.100.1
    Infos zur Fritzbox mit der IP 192.168.100.1


Kommandos:

extip, extipv4, und extipv6:
Zeigt die externen IPv4/v6-Adresse an (letztere mit Prefix).


conninfo: Zeigt Informationen und Status dr Internetverbindung an.


connstat: Zeigt des Status der Internetverbindung an.


ddnsinfo: Zeigt Informationen und Status eines Dynaminc DNS Service an.


timeinfo:
Zeigt Informationen und Status der NTP-Server und weitere Zeitinformationen an.


wlancount:
Zeigt die Anzahl der WLAN-APs an (2,4 GHz, 5 GHz, Gaeste-WLAN), wobei
versucht wird, den Typ der WLAN-APs aus der Fritzbox zu ermitteln, der
Hinweis presumed (vermutet) oder detected (ermittelt) in der Ausgabe
zeigt dies an.


wlan?info: Gibt Informationen zu einem der WLANs aus (?=1..4), wobei
versucht wird, den Typ des WLAN-APs aus der Fritzbox zu ermitteln, der
Hinweis presumed (vermutet) oder detected (ermittelt) in der Ausgabe
zeigt dies an.


wlanswitch:
Schaltet WLAN komplett ein oder aus. Dieses Kommando arbeitet wie die
Hardwaretaste an der Fritzbox. Die WLANs muessen in der Fritzbox komplett
konfiguriert sein. Ist dies nicht der Fall, kommt es zu Fehlerzustaenden
im WLAN-Teil der Fritzbox, die einen Reboot erforderlich machen.


wlan?switch:
Schaltet das betreffende WLAN ein bzw. aus (?=1..4). Die WLANs muessen
in der Fritzbox komplett konfiguriert sein, damit sie geschaltet
werden koennen. Ist dies nicht der Fall, kommt es zu Fehlerzustaenden
im WLAN-Teil der Fritzbox, die einen Reboot erforderlich machen.


dectinfo:
Zeigt eine Liste alle Dect-Telefone an.


deflectionsinfo:
Zeigt eine Liste aller Rufumleitungen und -sperren an. In der Ausgabe werden
diese von "1" ausgehend durchnummeriert; durch Angabe der Option
--showfritzindexes wird mit "0" beginnend nummeriert, wie es die Fritzbox
intern macht. Soll eine Deflection mittels der TR-064-Funktion
"SetDeflectionEnable" an- oder ausgeschaltet werden, ist der Index ausgehend
von "0" anzugeben.


homeautoinfo:
Gibt Informationen zu Homeautomation/Smarthome-Geraeten aus.
Der Index wird ab "1" durchnummeriert, ist eine Nummerierung ab "0" gewuenscht,
wie es intern die Fritzbox macht, ist die Option --showfritzindexes an der
Kommandozeile hinzuzufuegen.

Das Kommando kann durch Suchmasken verfeinert werden, wobei alle angegebenen
Suchmasken, die auch als Reg-Exp definiert werden koennen, gleichzeitig
erfuellt sein muessen. Die Suchmasken sind zwingend in Hochkommas anzugeben:

--searchhomeautoain "<text>"
--searchhomeautodeviceid "<text>"
--searchhomeautodevicename "<text>"


homeautoswitch "<ain>":

Schaltet den mittels AIN-Adresse angegebenen Smarthome-Schalter
an oder aus, wobei die AIN immer in Anfuehrungszeichen anzugeben ist.
Dies funktioniert nur fuer Schalter, die der Fritzbox bekannt sind.


homepluginfo:
Zeigt eine Liste alle Homeplug/Powerline-Geraete an.
Der Index wird ab "1" durchnummeriert, ist eine Nummerierung ab "0" gewuenscht,
wie es intern die Fritzbox macht, ist die Option --showfritzindexes an der
Kommandozeile hinzuzufuegen.
Der Index wird ab "1" durchnummeriert, ist eine Nummerierung ab "0" gewuenscht,
wie es intern die Fritzbox macht, ist die Option --showfritzindexes an der
Kommandozeile hinzuzufuegen.


hostsinfo:
Zeigt einer Liste aller Hosts mit folgenden Informationen an.


hostbyipinfo <ip>:
Gibt Informationen ueber den mittels IP-Adresse angegebenen Host aus.


wanaccessinfo <ip>:
Zeigt fuer den mittels der IP-Adresse angegebenen Host an, ob der Zugriff
auf das WAN-Interface erlaubt ist. Dies funktioniert nur fuer Hosts, die
der Fritzbox bekannt sind.


wanaccessswitch <ip>:
Schaltet den WAN-Zugriff fuer den mittels der IP-Adresse angegebenen Host
ein bzw. aus. Dies funktioniert nur fuer Hosts, die der Fritzbox bekannt
sind. Ein Client erhaelt nur dann Zugriff auf das WAN-Interface, wenn
sowohl dieser Schalter als auch das in der Web-UI zugeordnete Befehl
dies erlauben.


autowolinfo <mac>|<ip>:
Zeigt fuer den mittels der MAC- oder IP-Adresse angegebenen Host die Auto WOL
Konfiguration an. Dies funktioniert nur fuer Hosts, die der Fritzbox
bekannt sind.


autowolswitch <mac>|<ip>:
Schaltet Auto WOL fuer den mittels der MAC- oder IP-Adresse angegebenen Host
ein bzw. aus. Dies funktioniert nur fuer Hosts, die der Fritzbox bekannt sind.


wolclient <mac>|<ip>:
Weckt den mittels der MAC-oder IP-Adresse angegebenen Client auf. Dies
funktioniert nur fuer Clients, die der Fritzbox bekannt sind.

Hinweis:
Die MAC-Adresse ist immer in der Form
   xx:xx:xx:xx:xx:xx
anzugeben, wobei fuer die x die Zahlen 0-9 oder die Buchstaben a-f in Gross- oder
Kleinschreibung stehen. Eine fuehrende 0 darf nicht ausgelassen werden!


storageinfo: Zeigt den Status des FTP- und Samba-Servers an.


ftpswitch: Schaltet den internen FTP-Server an bzw. aus.


ftpwanswitch: Schaltet den externen FTP-Server an bzw. aus.


ftpwansslswitch: Schaltet auf dem externen FTP-Server SSLonly an bzw. aus.

Hinweis:
Einige Fritzboxen scheinen die Schalter "externer FTP-Server" und
"SSLOnly auf externem FTP-Server" zu vertauschen. In diesem Fall kann
in der Konfigurationsdatei die Option "FBREVERSEFTPWAN" auf "true"
gesetzt werden. Dieser Bug scheint in der Firmware 6.80 behoben zu sein.


smbswitch: Schaltet den internen Samba-Server an bzw. aus.


nasswitch:
Schaltet den internen FTP- und Samba-Server an bzw. aus. Fuer die
Nutzung des internen Medienservers muessen beide Server aktiviert werden.


upnpmediainfo: Zeigt Informationen zum UPnP- und Medienserver-Status an.


upnpswitch: Schaltet die Anzeige von Statusinformationen per UPnP an bzw. aus.


mediaswitch: Schaltet den Medienserver an bzw. aus.


taminfo: Zeigt Informationen zu den Anrufbeantwortern an.


tamcap: Zeigt die verfuegbare Aufnahmekapazitaet der Anrufbeantworter an.


tamswitch <index>:
Schaltet den durch Index angegebenen Anrufbeantworter an oder aus. Je nach
Firmware und Model ist Index eine Zahl zwischen 0 und 4. Die Ausfuehrung
dieses Kommandos legt Anrufbeantworter an, auch wenn diese vorher in
der Weboberflaeche der Fritzbox nicht definiert waren. Auf einer 7490 mit
Firmware 7.01 konnte beobachtet werden, dass nach Aktivieren aller 10
Anrufbeantworter die Anrufbeantworterseite auf der Weboberflaeche der leer
blieb und nur Wiederherstellen eines Konfiguration-Backups repariert
werden konnte.


alarminfo:
Zeigt Informationen zu den Weckern an.


alarmswitch <index>:
Schaltet den durch Index (0-2) angegebenen Wecker an oder aus.


reconnect: Erneuert die Internetverbindung


reboot: Rebootet die Fritzbox


savefbconfig:
Sichert die Konfiguration der Fritzbox in einen definierbaren Pfad unter dem
Namen:

<waehlbarer Prefix>_Modellname_Seriennummer_Firmwareversion_YYYYMMDD_hhmmss.
<waehlbarer Suffix>


updateinfo: Zeigt Informationen zu verfuegbaren Firmwareupdates an.


tr69info:
Zeigt die Information ueber durch den Provider initiierte Updates via TR-069
Protokoll an.


deviceinfo:
Liefert Informationen zur eigenen Fritzbox; insbesondere auch die Art der
Anbindung ans Internet PPPoE oder IP.


devicelog:
Zeigt das Log der Fritzbox an. Bei Angabe der Option --rawdevicelog geschieht
dies unformatiert und ohne Kopfzeile.


listxmlfiles:
Zeigt eine Liste aller xml SOAP Beschreibungsdateien der Fritzbox an.


showxmlfile:
Zeigt die xml SOAP Beschreibungsdateien der Fritzbox an. Als Parameter ist der
Dateiname der gewuenschten Datei anzugeben, sofern eine andere Datei als
tr64desc.xml angezeigt werden soll, z. B.:

fbtr64toolbox.sh showxmlfile igddesc.xml

Die xml-Dokumente tr64desc.xml, igddesc.xml, fboxdesc.xml und usbdesc.xml
beschreiben alle verfuegbaren Services. Insbesondere die Existenz von
fboxdesc.xml und usbdesc.xml ist abhaengig von Typ und Firmware der Fritzbox.

Weitere xml-Dokumente sind in den SCPDURL-TAGs von tr64desc.xml, igddesc.xml,
fboxdesc.xml und usbdesc.xml angegeben und enthalten detaillierte
Informationen zu den Services, z. B.:

fbtr64toolbox.sh showxmlfile deviceconfigSCPD.xml

Mit der Option --soapfilter werden nur die fuer die Erstellung eigener
SOAP-Request notwendigen Informationen ausgefiltert.

Im Falle von tr64desc.xml, igddesc.xml, fboxdesc.xml und usbdesc.xml werden
folgende Informationen ausgegeben (Ausschnitt):

fbtr64toolbox.sh showxmlfile tr64desc.xml --soapfilter

ergibt:

[...]
<serviceType>urn:dslforum-org:service:DeviceInfo:1</serviceType>
<controlURL>/upnp/control/deviceinfo</controlURL>
<SCPDURL>/deviceinfoSCPD.xml</SCPDURL>
--------------------
<serviceType>urn:dslforum-org:service:DeviceConfig:1</serviceType>
<controlURL>/upnp/control/deviceconfig</controlURL>
<SCPDURL>/deviceconfigSCPD.xml</SCPDURL>
--------------------
[...]

Fuer die in den SCPDURL-Tags von tr64desc.xml, igddesc.xml, fboxdesc.xml und
usbdesc.xml angegebenen xml-Dateien werden Aktionen und ihre Argumente
(inklusive Richtung und Datentyp) angezeigt, z. B.:

fbtr64toolbox.sh showxmlfile deviceconfigSCPD.xml --soapfilter

und ergibt folgende Ausgabe:

Filtered Content of deviceconfigSCPD.xml (FRITZ!Box 7490 113.06.83@abc.def.ghi.jkl)
action: GetPersistentData
   out: NewPersistentData string
action: SetPersistentData
    in: NewPersistentData string
action: ConfigurationStarted
    in: NewSessionID string
action: ConfigurationFinished
   out: NewStatus string
action: FactoryReset
action: Reboot
action: X_GenerateUUID
   out: NewUUID uuid
action: X_AVM-DE_GetConfigFile
    in: NewX_AVM-DE_Password string
   out: NewX_AVM-DE_ConfigFileUrl string
action: X_AVM-DE_SetConfigFile
    in: NewX_AVM-DE_Password string
    in: NewX_AVM-DE_ConfigFileUrl string
action: X_AVM-DE_CreateUrlSID
   out: NewX_AVM-DE_UrlSID string


createsoapfiles:
Erzeugt aus den auf der Fritzbox gespeicherten XML-Dokumenten SOAP-Dateien.
Das Zielverzeichnis ist mit vollem Pfad anzugeben. Siehe hierzu die
Beschreibung dritten Kapitel dieses Dokumentes. Ein erneuter Aufruf dieser
Funktion loescht zunaechst die bisherigen Dateien im Zielverzeichnis.


mysoaprequest:
Dieses Kommando erlaubt die Ausfuehrung beliebiger SOAP-Request ueber die
TR-064-Schnittstelle der Fritzbox. Der Befehl

fbtr64toolbox.sh writesoapfile [<fullpath>/<file>]

erstellt eine SOAP-Beispieldatei unter dem dem angegebenen Dateinamen,
der zwingend mit vollem Pfad anzugeben ist, oder eine Beispieldatei
namens fbtr64toolbox.samplesoap im Home-Verzeichnis.

Der Befehl kann jederzeit wiederholt werden, z. B. um die Datei bei
zukuenftigen Versionen des Skripts zu aktualisieren. Vorgenommene Einstellungen
bleiben dabei erhalten.

In dieser Datei wird erlaeutert, wie man einen SOAP-Request erstellt, der dann
mittels

fbtr64toolbox.sh mysoaprequest <datei mit dem soap request>

ausgefuehrt wird.

In dieser SOAP-Steuerdatei koennen auch alle variable="wert" Zeilen der normalen
Konfigurationsdatei $[HOME}/.fbtr64toolbox angegeben werden und haben Vorrang
vor den entsprechenden Werten der Konfigurationsdatei.

Hierzu am Ende der SOAP-Steuerdatei die Marker-Zeile

# [GENERAL_CONFIGURATION]

mit Zeilenvorschub hinzufuegen und darunter die gewuenschten Konfigurationszeilen
einfuegen.

Fehlt die Marker-Zeile oder ist falsch geschrieben, gehen bei einem Update
der SOAP-Steuerdatei mittels des writesoapfile-Kommandos diese hinzugefuegten
Optionen verloren.

Ein SOAP-Request kann auch direkt ueber die Kommandozeile angegeben werden. Dabei
sind die Parameter wie in der SOAP-Beispieldatei ergaenzt um "--SOAP" und dem
Wert nach einen Leerzeichen anzugeben.

Hierzu ein Beispiel (alles in einer Zeile):

fbtr64toolbox.sh mysoaprequest --SOAPdescfile tr64desc.xml --SOAPcontrolURL
 deviceinfo --SOAPserviceType DeviceInfo:1 --SOAPaction GetDeviceLog --SOAPdata ""
 --SOAPtype https

Sind fuer SOAPdata keine Werte zu uebergeben, kann der Parameter entfallen.
SOAPtype kann ebenfalls entfallen, wobei dann https angenommen wird, ebenso
SOAPdescfile, wobei dieser Parameter mit tr64desc.xml vorbesetzt wird.

Wird eine Headerzeile bei der Ausgabe gewuenscht, ist die Option
--SOAPtitle "mein text" der Kommandozeile hinzuzufuegen, wobei dann automatisch
ein standardisierter Geraetetext wie
"(FRITZ!Box 7490 113.06.83@192.168.178.1)" hinzugefuegt wird.

Unter https://avm.de/service/schnittstellen findet man detaillierte Informationen
und Dokumente zur SOAP-Schnittstelle.

Unter dem Menue-Punkt "Create sample soap files from fritzbox documents" (siehe
oben unter 1. Das Menue) koennen fuer alle TR-04-Funktionen der eigenen Fritzbox
SOAP-Beispieldateien erzeugt werden. Eine Beschreibung dieser Dateien folgt im
3. Kapitel dieser Dokumentation.

Wird eine solche SOAP-Datei ausgefuehrt, haben Kommandozeilenparameter Vorrang
vor den Werten innerhalb der SOAP-Datei, z. B.

fbtr64toolbox.sh mysoaprequest deviceinfoSCPD.xml.GetSecurityPort_1 --SOAPtype http

nutzt nun http statt des in der SOAP-Datei angegebenen https.

Insbesondere der --SOAPdata Kommandozeilenparameter kann sinnvoll dazu genutzt
werden, eine SOAP-Datei fuer verschiedene Eingabewerte auszufuehren, ohne
jedesmal die SOAP-Datei zu editieren. Findet sich z. B. in der SOAP-Datei die
folgende data-Sektion (ui2 steht fuer den Datentyp; siehe 3. Die
SOAP-Beispieldateien)

data="
       <NewIndex>ui2</NewIndex>
     "

kann man die SOAP-Datei ohne Aenderung fuer einen bestimmten Index ausfuehren:

fbtr64toolbox.sh mysoaprequest ... --SOAPdata "<NewIndex>1</NewIndex>"


writeconfig:
Schreibt die Konfigurationsdatei; siehe Erlaeuteungen am Beginn dieses Dokuments

help|--help|-h: Zeigt eine Hilfeseite an.


Folgende Parameter, die Vorrang vor den in der Konfigurationsdatei oder einer
SOAP-Steuerdatei gesetzten Optionen haben, ergaenzen die Kommandos:

Parameter                        Benutzt vom Kommando
--fbip <ip address>|<fqdn>       Alle ausser writeconfig and writesoapfile
    IP-Adresse oder FQDN der Fritzbox

--description "<text>"              add, enable, disable
    Beschreibung der Portfreigabe.

--extport <port number>             add, enable, disable, del
    Externen Port der Portfreigabe.

--intclient <ip address>            add, enable, disable
    Interner Zielrechner der Portfreigabe.

--intport <port number>             add, enable, disable
    Interner Port der Portfreigabe.

--protocol <TCP|UDP>                add, enable, disable, del
    Protokolltyp der Portfreigabe.

--active                            add, *switch
--inactive                          add, *switch
    Aktivierungs-/Deaktivierungsschalter

--searchhomeautoain "<text>"        homeautoinfo
    Suchmaske fuer die AIN eines Homeautomation/Smarthome-Geraetes.
--searchhomeautodeviceid "<text>"   homeautoinfo
    Suchmaske fuer die Device-ID eines Homeautomation/Smarthome-Geraetes.
--searchhomeautodevicename "<text>" homeautoinfo
    Suchmaske fuer den Devicenamen AIN eines Homeautomation/Smarthome-Geraetes.
    In diesen search-Parametern kann die Suchmaske Text oder eine Reg-Exp sein.

--showWANstatus                     hostsinfo
    Zeigt fuer jeden Host an, ob Zugriff auf das WAN-Interface besteht. Diese
    Option erfordert mindestens Fritzbox-Firmware 7.20 und wird automatisch
    deaktiviert, falls die Firtzbox die notwendige Funktion nicht enthaelt.
--showWOLstatus                     hostsinfo
    Zeigt fuer jeden Host an, ob Wake-on-Lan aktiviert ist.
--showhosts "<active|inactive>"     hostsinfo
    Zeigt nur die aktiven bzw. inaktiven Hosts an.

--ftpwansslonlyon (**)              ftpwanswitch
--ftpwansslonlyoff (**)             ftpwanswitch
--ftpwanon (**)                     ftpwansslswitch
--ftpwanoff (**)                    ftpwansslswitch
    (Bitte Hinweis bei der Erlaeuterung der Kommandos
    ftpwanswitch iund ftwansslswitch beachten!)
--mediaon (**)                      upnpswitch
--mediaoff (**)                     upnpswitch
--upnpon (**)                       mediaswitch
--upnpoff (**)                      mediaswitch
    Schaltet eine weitere Funktion an bzw. aus, z. B.
    fbtr64toolbox.sh upnpswitch --active --mediaon
    schaltet sowohl die Statusinformationen per UPnP
    als auch den Medienserver gleichzeitig an.
    Wird die Option bei gekoppelten Funktionen nicht
    angegeben, bleibt der vorige Schaltzustand der
    gekoppelten Funktion unveraendert.

--showfritzindexes                  show, deflectionsinfo,
                                    homeautoinfo, homepluginfo, hostsinfo
    Beginnt den Index in diesen Listen mit "0" statt "1", was der internen
    Nummerierung der Fritzbox entspricht. Soll ein ermittelter Index in
    einer anderen TR-64-Funktion als Eingabewert genutzt werden, ist
    in der Regel von einer ab "0" ausgehenden Nummerierung auszugehen.

--nowrap                            deviceinfo
    Zeigt die Zeile fuer den letzten Event ohne Zeilenumbruch an.

--rawdevicelog                      devicelog
    Zeigt das Log unformatiert und ohne Kopfzeile an.

--soapfilter                        showxmlfile
    Zeigt nur die moeglichen Aktionen und die zugehoerigen
    Argumente (inklusive Richtung und Datentyp) an.

--fbconffilepath "<abs path>"       savefbconfig
--fbconffileprefix "<text>"         savefbconfig
--fbconffilesuffix "<text>"         savefbconfig
--fbconffilepassword "<text>"       savefbconfig
    Parameter zur Definition des Pfades und Dateinamens
    bzw. des Passworts der Fritzbox-Konfigurationsdatei.

Erklaerungen fuer diese Parameter stehen in der SOAP-Beispieldatei.
--SOAPtype <https|http>             mysoaprequest
--SOAPdescfile <xmlfilename>        mysoaprequest
--SOAPcontrolURL <URL>              mysoaprequest
--SOAPserviceType <service type>    mysoaprequest
--SOAPaction <function name>        mysoaprequest
--SOAPdata "<function data>"        mysoaprequest
--SOAPsearch "<search text>|all"    mysoaprequest
--SOAPtitle "<text>"                mysoaprequest

--experimental
    Schaltet als experimentell eingestufte Kommandos frei.

--debugfb
    Aktiviert eine Debug-Ausgabe zur Fehlersuche.
--verbose
    Zeigt die Rueckgabecodes aller ausgefuehrten TR-064-Funktionen an.


3. Die SOAP-Beispieldateien

Diese Beispieldateien erhalten Dateinamen nach folgendem Schema:

<Name des Fritzbox-Dokumentes>.<Funktion>_<Servicetype-Nummer>

also z. B.

deviceinfoSCPD.xml.GetInfo_1

Falls es mehrere Komponenten eines Servicetypes gibt, z. B. die
verschiedenen WLANs, unterscheiden diese sich bei gleicher Funktion
durch die Servicetype-Nummer.

In der Regel sind diese Beispieldateien dann anzupassen, wenn eine
TR-064-Funktion die Uebergabe von Werten erfordert, welches in der
Beispieldatei daran zu erkennen ist, dass sich darin ein Block wie

data="
       <Variable1><Typ></Variable1>
       ...
       <VariableN><Typ></VariableN>
     "

befindet. Hier ist <Typ> durch eine dem Datentyp entsprechenden Wert (Zahl,
Zeichenfolge, ...) zu ersetzen. Hierzu ist die offizielle Entwickler-
dokumentation von AVM zu Rate zu ziehen:

    https://avm.de/service/schnittstellen

Wenn als Datentyp boolean angegeben ist, ist in der Regel 0 fuer false und
1 fuer true anzugeben.

Beispieldateien fuer Funktionen, die keine weiteren Parameter erfordern,
enthalten die Zeile

data=""

und koennen sofort genutzt werden.

Man sollte sich aber immer ueber die Wirkung eines TR-064-Funktion im Klaren
sein, da eventuell Veraenderungen an der Fritzbox vorgenommen werden, so wird
die Beispieldatei deviceconfigSCPD.xml.FactoryReset_1 ohne weitere Rueckfrage
die Fritzbox auf Werkseinstellungen zuruecksetzen.


Stand: 2023-07-17
Marcus Roeckrath
