# fbtr64toolbox
Bash-TR-064-Script for AVM fritzboxes

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

Auf dem Zielsystem benötigte Tools: grep, sed, curl, wget und ksh

Vor Benutzung bitte unbedingt die Dokumentation im Archiv unter
/usr/share/doc/fbtr64toolbox/fbtr64toolbox.txt lesen.

Das Skript wurde in folgenden System getestet:
- eisfair (Linux-Serverdistribution eisfair.org)
- OpenSuSE
- Ubuntu (im Windows Subsystem for Linux WSL1 in Windows 10)
- Debian (im Windows Subsystem for Linux WSL1 in Windows 10)
- Raspbian
