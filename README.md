# WinApps-Launcher
Taskbar Launcher for [WinApps](https://github.com/winapps-org/winapps).
Feel free to fork, submit pull requests, write issues and promote this project to grow the WinApps community!

![WinApps Launcher Demonstration](demo.gif)

## Installation Instructions
### Dependencies
WinApps should have already brought in everything that the script will need, however a package know as yad may be missing, you can use the instructions below to install it:
#### Debian
    sudo apt install yad
#### Fedora/RHEL
    sudo dnf install yad
#### Arch
    sudo pacman -Syu --needed yad
#### OpenSUSE
    sudo zypper install yad
    
### Installation
1. Open the terminal of your choice.

2. Now, download the git repository with git clone (If you don't want to use git, you can also use wget):
   ```bash
    git clone https://github.com/winapps-org/winapps-launcher/
    ```

3. Once the clone has completed, open the `winapps-launcher` folder:
    ```bash
    cd winapps-launcher
    ```

3. Once there, mark the `WinAppsLauncher.sh` script as executable. 
    ```bash
    chmod +x WinAppsLauncher.sh
    ```

4. Finally, Run the `WinAppsLauncher.sh` script.
    ```bash
    ./WinAppsLauncher.sh
    ```

5. (Optional) You can also open the `winapps-launcher.service` with a text editor and use the instructions within to configure a user service that can automatically start the WinApps Launcher on boot!
