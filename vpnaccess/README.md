# FernUni Hagen VPN (openconnect) Scripts

This directory contains two scripts to simplify the VPN connection to FernUni Hagen using `openconnect` and the GNOME Keyring.

* `setup-vpn-secret.sh`: A **one-time** setup script to securely store your VPN username and password in the local keyring.
* `fernuni-vpn.expect`: An `expect` script that automatically fetches your credentials, starts the VPN connection, and prompts you only for your final access token (MFA/2FA).

## Prerequisites

You must have the following software installed. (Package names are examples from Arch Linux):

* `openconnect`: The VPN client.
* `expect`: For automating the login process.
* `libsecret`: Provides `secret-tool` to access the keyring.
* `gnome-keyring`: A running keyring service to store the credentials.

## Step 1: Setup (One-Time Only)

This script saves your username and password so you don't have to type them in every time.

1.  Make the script executable:
    ```bash
    chmod +x setup-vpn-secret.sh
    ```
2.  Run the script:
    ```bash
    ./setup-vpn-secret.sh
    ```
3.  Follow the prompts to enter your VPN username and password.

## Step 2: Usage (Connecting to the VPN)

1.  Make the connection script executable:
    ```bash
    chmod +x fernuni-vpn.expect
    ```
2.  **Important**: Before running the script, you must refresh your `sudo` timestamp. Run:
    ```bash
    sudo -v
    ```
    *(This ensures the `expect` script can successfully run the `sudo openconnect` command).*

3.  Now, start the VPN connection:
    ```bash
    ./fernuni-vpn.expect
    ```
4.  The script will automatically enter your username and password. Wait until you are prompted for your **access token** (MFA), then type it in and press Enter.

## Important Notes

* **Sudo Configuration**: This script *requires* `sudo` to use a global timestamp, not one tied to a specific terminal. Before this script can work, you must edit your `sudoers` configuration (using `sudo visudo`) to include a line for your user:
    ```
    # Example for user 'username'
    Defaults:username    timestamp_type=global
    ```
    (Replace `username` with your actual username). This ensures that the `sudo -v` command in one terminal is respected by the `expect` script when it runs `sudo openconnect`.

* **Graphical Session Required**: These scripts depend on the GNOME Keyring. They are designed to be run from within a graphical desktop session (like GNOME, KDE, XFCE, etc.).

* **No SSH Support**: The scripts will **not** work over a standard SSH connection, as the keyring is typically locked or unavailable in that environment.