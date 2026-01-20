# Arch Linux Update Checker

This Zsh script safely checks for available Arch Linux package updates *before* you decide to run the actual update.

## What it Does

This script provides a "safe" way to see pending updates.

Its main feature is that it does **not** refresh your main system's package database (it does not run `sudo pacman -Sy` on your live system just to check).

Instead, it:
1.  Creates a temporary, separate database.
2.  Refreshes that temporary database.
3.  Compares your installed packages against it to find updates.
4.  Shows you a detailed list of what is available.
5.  Asks you if you want to proceed with the real update (`sudo pacman -Syu`).

This is useful if you want to check for updates without modifying your system's "last sync" time.

## Usage

1.  Make the script executable:
    ```bash
    chmod +x arch-update-check.zsh
    ```
2.  Run the script:
    ```bash
    ./arch-update-check.zsh
    ```

## Requirements

* `zsh`
* `sudo` (required by the script to manage the temp database and run the final update)