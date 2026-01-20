# Arch Linux auf neue SSD umziehen

## Ist-Zustand der Dual-Boot-Konfiguration

Die aktuelle **Arch Linux Dual-Boot** befindet sich auf der alten NVMe-SSD (`/dev/nvme1n1`), die auch eine Windows 11-Installation (`nvme1n1p3`) enthält. Die alte Linux-Installation nutzt dort drei Partitionen: **EFI** (`nvme1n1p1`), **Swap** (`nvme1n1p4`) und die **Root-Partition** (`nvme1n1p6`).

Für die Migration wurde eine **neue, leere NVMe-SSD** (`/dev/nvme0n1`) in den Rechner verbaut, die nun bereit zur Partitionierung und zum Empfang der geklonten Arch Linux-Daten ist.

## Workflow

### Phase 1: Vorbereitung im UEFI und Arch Live System

1.  **UEFI-Zugriff:** Rechner mit eingestecktem Arch Linux Live USB-Stick starten. Sofort die Taste **`Entf`** (Delete) drücken, um das MSI UEFI/BIOS aufzurufen.
2.  **Boot-Auswahl:** Im UEFI zum Boot-Menü navigieren und den **UEFI-Eintrag** des USB-Sticks auswählen, um das Arch Linux Live System zu starten.
3.  **Tastatur-Layout einstellen:** Sobald die Arch Live Console kommt, das deutsche Tastaturlayout einstellen.
    ```bash
    loadkeys de-latin1
    ```



### Phase 2: Partitionierung und Formatierung der neuen SSD

Ziel ist die neue SSD (`/dev/nvme0n1`) mit 1 GiB EFI, 4 GiB Swap und dem Rest als Root-Partition.

#### 1\. Partitionierung mit `fdisk`

Starte das Partitionierungsprogramm für die neue Platte:

```bash
fdisk /dev/nvme0n1
```

Folgende Kommandos im `fdisk`-Prompt ausführen:

| Aktion | fdisk-Kommando |
| :--- | :--- |
| Neue GPT-Tabelle erstellen | `g` |
| **Partition 1 (EFI)** erstellen | `n` (Partition 1), Enter (erster Sektor), `+1G` (Größe) |
| Typ für P1 setzen (EFI System) | `t`, `1` (Code für EFI System) |
| **Partition 2 (Swap)** erstellen | `n` (Partition 2), Enter, `+4G` (Größe) |
| Typ für P2 setzen (Linux swap) | `t`, `2`, `19` (Code für Linux swap) |
| **Partition 3 (Root)** erstellen | `n` (Partition 3), Enter, Enter (Rest der Platte) |
| Änderungen schreiben und beenden | `w` |

#### 2\. Formatierung der Partitionen

```bash
# 1. EFI System Partition (P1) formatieren (FAT32)
mkfs.fat -F 32 /dev/nvme0n1p1

# 2. Swap-Partition (P2) initialisieren und aktivieren
mkswap /dev/nvme0n1p2
swapon /dev/nvme0n1p2

# 3. Root-Partition (P3) formatieren (ext4)
mkfs.ext4 -L arch /dev/nvme0n1p3
```

### Phase 3: Datenmigration und fstab-Abgleich

#### 1\. Partitionen einbinden und Daten kopieren

```bash
# Neue Root-Partition als Ziel
mount /dev/nvme0n1p3 /mnt

# Alte Root-Partition als Quelle
mkdir /mnt/old_system
mount /dev/nvme1n1p6 /mnt/old_system

# Daten kopieren (rsync)
rsync -aAXv /mnt/old_system/ /mnt/ --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/lost+found"}
```
#### 2\. fstab-Abgleich und Bereinigung

Hier sichern wir die mitkopierten (`rsync`) externen Einträge, bereinigen die doppelten System-Einträge und erstellen die `fstab` neu.

```bash
# 1. Alte Quelle aushängen (Vorbereitung für genfstab)
umount /mnt/old_system
rmdir /mnt/old_system

# 2. Neue EFI-Partition mounten
mkdir -p /mnt/boot/efi 
mount /dev/nvme0n1p1 /mnt/boot/efi

# 3. fstab für den Abgleich sichern (enthält alte und externe Einträge)
cp /mnt/etc/fstab /mnt/etc/fstab.backup_external

# 4. fstab leeren und mit den NEUEN System-Partitionen generieren
> /mnt/etc/fstab
genfstab -U /mnt > /mnt/etc/fstab

# 5. Externe Einträge hinzufügen (Beispiel: /mnt/lightroomssd)
# Wir suchen nach der Zeile für /mnt/lightroomssd im Backup und hängen sie an
echo "" >> /mnt/etc/fstab # Optional: Eine Leerzeile für die Übersicht
grep 'lightroomssd' /mnt/etc/fstab.backup_external >> /mnt/etc/fstab

# 6. NEUE fstab zur Überprüfung anzeigen
cat /mnt/etc/fstab
```

*Prüfen, ob alle drei System-Partitionen (`/`, `/boot/efi`, `swap`) und `/mnt/lightroomssd`-Eintrag korrekt mit der richtigen UUID vorhanden sind.*


#### 4\. Bootloader und Initramfs aktualisieren

```bash
arch-chroot /mnt

# 1. Initramfs-Images neu generieren (empfohlen)
mkinitcpio -P

# 2. GRUB auf die neue SSD installieren
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch_NVMe0n1 --recheck /dev/nvme0n1

# 3. GRUB Konfigurationsdatei neu erstellen (findet Windows 11 auf nvme1n1)
grub-mkconfig -o /boot/grub/grub.cfg

# 4. Chroot-Umgebung verlassen
exit

# 5. Alle Partitionen aushängen
umount -R /mnt
```

### Phase 4: Abschluss und Neustart

1.  **Neustart:**
    ```bash
    reboot
    ```
2.  **UEFI-Einstellung:** Beim Start erneut die **`Entf`**-Taste drücken. Die **Boot-Priorität** auf den neuen UEFI-Eintrag **`Arch_NVMe0n1`** ändern.
3.  **Finalisierung im System:** Nach dem erfolgreichen Start von der neuen SSD:
    ```bash
    sudo mkinitcpio -P
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ```

### Phase 5: Bereinigung der alten Platte (`/dev/nvme1n1`)

Dieser Schritt wird **im erfolgreich gestarteten Arch Linux System** auf der neuen SSD ausgeführt.

#### 1\. Alte Linux-Partitionen löschen

Wir löschen die alte Swap (`p4`), Root (`p6`) und die ungenutzte Partition (`p2`). **Lösche auf keinen Fall `nvme1n1p1` (Windows EFI), `nvme1n1p3` (Windows) oder `nvme1n1p5` (Recovery)\!**

1.  **Alte Swap-Partition deaktivieren:**

    ```bash
    sudo swapoff /dev/nvme1n1p4
    ```

2.  **Partitions-Tool starten:**

    ```bash
    sudo fdisk /dev/nvme1n1
    ```

3.  **Lösch-Befehle im `fdisk`-Prompt:**

      * `p` (Aktuelle Partitionstabelle anzeigen und Nummern prüfen)
      * `d` (Löschen)
      * `6` (Partition **p6** löschen)
      * `d` (Löschen)
      * `4` (Partition **p4** löschen)
      * `d` (Löschen)
      * `2` (Partition **p2** löschen)
      * `w` (Änderungen speichern und beenden)

#### 2\. Speicherplatz zur Windows-Partition hinzufügen

Da die zu erweiternde Partition (`nvme1n1p3`) eine NTFS-Partition ist und sich jetzt direkt vor dem freien Speicherplatz befindet, ist es am einfachsten und sichersten, die Erweiterung **unter Windows** vorzunehmen.

1.  **Neustart** in Windows 11.
2.  Öffnen der **Datenträgerverwaltung** (Rechtsklick auf das Startmenü -\> Datenträgerverwaltung).
3.  Rechtsklick auf die Windows-Partition (`nvme1n1p3`).
4.  **Volume erweitern** wählen und den Anweisungen folgen, um den gesamten angrenzenden, nicht zugewiesenen Speicherplatz hinzuzufügen.

#### 3\. GRUB-Menü bereinigen

Nachdem die alten Linux-Partitionen gelöscht wurden, GRUB anweisen, die alten, nun nicht mehr bootfähigen Einträge zu entfernen.

1.  **Starte zurück in Arch Linux.**
2.  **GRUB-Konfiguration neu erstellen:**
    ```bash
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ```
    *Da die alten Linux-Partitionen nicht mehr existieren, wird `os-prober` (das Windows erkennt) sie nicht mehr finden, und sie werden aus dem Boot-Menü entfernt.*