# WinApps-Launcher
Taskbar Launcher for [WinApps](https://github.com/winapps-org/winapps).
Feel free to fork, submit pull requests, write issues and promote this project to grow the WinApps community!

![WinApps Launcher Demonstration](demo.gif)

## Installation Instructions
### Dependencies
WinApps should have already brought in everything that the script will need, however a package known as `yad` may be missing. You can use the instructions below to install it:

#### Debian / Zorin OS / Ubuntu / Linux Mint
    sudo apt install yad
#### Fedora/RHEL
    sudo dnf install yad
#### Arch
    sudo pacman -Syu --needed yad
#### OpenSUSE
    sudo zypper install yad
    
### Installation
1.  Ensure you have already installed [`WinApps`](https://github.com/winapps-org/winapps).

2.  Identify your WinApps source directory.
    *   For a local user installation: `~/.local/bin/winapps-src`
    *   For a system-wide installation: `/usr/local/bin/winapps-src`

3.  Set a variable in your terminal pointing to this directory. **Copy the line that matches your setup.**

    ```bash
    # FOR LOCAL INSTALL:
    WINAPPS_SRC_DIR="$HOME/.local/bin/winapps-src"

    # --- OR ---

    # FOR SYSTEM-WIDE INSTALL:
    WINAPPS_SRC_DIR="/usr/local/bin/winapps-src"
    ```

4.  Now, run the following commands to clone the repository and run the launcher. This will place `WinApps-Launcher` inside your existing `winapps-src` directory.

    ```bash
    # Clone the repository into the correct location
    git clone https://github.com/winapps-org/WinApps-Launcher.git "${WINAPPS_SRC_DIR}/WinApps-Launcher"

    # Mark the script as executable
    chmod +x "${WINAPPS_SRC_DIR}/WinApps-Launcher/WinApps-Launcher.sh"

    # Run the launcher
    "${WINAPPS_SRC_DIR}/WinApps-Launcher/WinApps-Launcher.sh"
    ```

5.  (Optional) You can open `${WINAPPS_SRC_DIR}/WinApps-Launcher/winapps-launcher.service` with a text editor and use the instructions within to configure a user service that can automatically start the WinApps Launcher on boot!
