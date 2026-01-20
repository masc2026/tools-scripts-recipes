#!/bin/bash

## Speichert Benutzername und Passwort für die VPN-Verbindung
## zur FernUni Hagen im GNOME-Keyring, sodass das Verbindungs-Script
## https://gist.github.com/simas2024/88c989f2d6ff2f8a5a69736a18e1305a#file-fernuni-vpn-expect
## die Zugangsdaten automatisch abrufen kann.
##
##
## Getestet unter Arch Linux.
## Benötigte Pakete (Arch Linux):
##   - gnome-keyring  (für den GNOME-Keyring-Dienst)
##   - libsecret      (stellt 'secret-tool' bereit)
##
## Hinweis:
## Dieses Script nutzt den GNOME-Keyring für die Speicherung/Abruf der Zugangsdaten.
## Der GNOME-Keyring steht in der Regel nur innerhalb einer laufenden GNOME- oder
## grafischen Desktop-Sitzung zur Verfügung. Bei reinem SSH-Login ist der Zugriff
## auf die gespeicherten Daten normalerweise nicht möglich.

# Passwort abfragen
read -p "VPN Benutzername: " USER
read -s -p "VPN Passwort: " PASS
echo

# Im GNOME-Keyring speichern
echo -n "$USER" | secret-tool store --label="FernUni VPN Password" vpn fernuni key user
echo -n "$PASS" | secret-tool store --label="FernUni VPN Password" vpn fernuni key password

echo "Benutzername und Passwort gespeichert."
