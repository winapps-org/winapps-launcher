# WinApps-Launcher
Taskbar Launcher for [WinApps](https://github.com/winapps-org/winapps).
Feel free to fork, submit pull requests, write issues and promote this project to grow the WinApps community!

![WinApps Launcher Demonstration](demo.gif)

## Installation Instructions
### Dependencies
WinApps should have already brought in everything that the script will need, however a package known as `yad` may be missing. You can use the instructions below to install it:

#### Debian
    sudo apt install yad
#### Fedora/RHEL
    sudo dnf install yad
#### Arch
    sudo pacman -Syu --needed yad
#### OpenSUSE
    sudo zypper install yad
    
### Installation
1. Install [`WinApps`](https://github.com/winapps-org/winapps).

2. Navigate to the `WinApps-Launcher` folder.

    ```bash
    cd ~/.local/bin/winapps-src/WinApps-Launcher
    ```

3. Mark the `WinApps-Launcher.sh` script as executable. 

    ```bash
    chmod +x WinApps-Launcher.sh
    ```

4. Run `WinApps-Launcher.sh`.

    ```bash
    ./WinApps-Launcher.sh
    ```

5. (Optional) You can also open `winapps-launcher.service` with a text editor and use the instructions within to configure a user service that can automatically start the WinApps Launcher on boot!
