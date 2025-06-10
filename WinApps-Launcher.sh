#!/usr/bin/env bash

### GLOBAL CONSTANTS ###
# ANSI Escape Sequences
declare -rx ERROR_TEXT="\033[1;31m"
declare -rx DEBUG_TEXT="\033[1;33m"
declare -rx STATUS_TEXT="\033[1;32m"
declare -rx ADDRESS_TEXT="\033[1;34m"
declare -rx PATH_TEXT="\033[1;35m"
declare -rx RESET_TEXT="\033[0m"

# Exit Codes
declare -rx EC_DSPLY_UNSET=1
declare -rx EC_CDIR_FAILED=2
declare -rx EC_MISSING_DEP=3
declare -rx EC_NO_WACONFIG=4
declare -rx EC_BAD_BACKEND=5
declare -rx EC_WIN_NOT_SPEC=6
declare -rx EC_NO_WIN_FOUND=7

# Paths
declare -rx ICONS_PATH="./Icons"
declare -rx APPDATA_PATH="${HOME}/.local/share/winapps"
declare -rx CONFIG_PATH="${HOME}/.config/winapps"
declare -rx CONFIG_FILE="${CONFIG_PATH}/winapps.conf"
declare -rx COMPOSE_FILE="${CONFIG_PATH}/compose.yaml"
declare -rx USER_WINAPPS_APPLICATIONS="${HOME}/.local/share/winapps/apps"
declare -rx SYSTEM_WINAPPS_APPLICATIONS="/usr/local/share/winapps/apps"

# Menu Entries
declare -rx MENU_APPLICATIONS="Applications!bash -c app_select!${ICONS_PATH}/Applications.svg"
declare -rx MENU_FORCEOFF="Force Power Off!bash -c force_stop_windows!${ICONS_PATH}/ForceOff.svg"
declare -rx MENU_KILL="Kill FreeRDP!bash -c kill_freerdp!${ICONS_PATH}/Kill.svg"
declare -rx MENU_PAUSE="Pause!bash -c pause_windows!${ICONS_PATH}/Pause.svg"
declare -rx MENU_POWEROFF="Power Off!bash -c stop_windows!${ICONS_PATH}/Power.svg"
declare -rx MENU_POWERON="Power On!bash -c start_windows!${ICONS_PATH}/Power.svg"
declare -rx MENU_QUIT="Quit!quit!${ICONS_PATH}/Quit.svg"
declare -rx MENU_REBOOT="Reboot!bash -c reboot_windows!${ICONS_PATH}/Reboot.svg"
declare -rx MENU_REDMOND="Windows!bash -c launch_windows!${ICONS_PATH}/Redmond.svg"
declare -rx MENU_REFRESH="Refresh Menu!bash -c refresh_menu!${ICONS_PATH}/Refresh.svg"
declare -rx MENU_RESET="Reset!bash -c reset_windows!${ICONS_PATH}/Reset.svg"
declare -rx MENU_RESUME="Resume!bash -c resume_windows!${ICONS_PATH}/Resume.svg"
declare -rx MENU_HIBERNATE="Hibernate!bash -c hibernate_windows!${ICONS_PATH}/Hibernate.svg"

# Other
declare -rx VM_NAME="RDPWindows"
declare -rx CONTAINER_NAME="WinApps"
declare -rx DEFAULT_FLAVOR="docker"

### GLOBAL VARIABLES ###
declare -x WINAPPS_PATH="" # Generated programmatically following dependency checks.
declare -x WAFLAVOR=""     # As specified within the WinApps configuration file.

### FUNCTIONS ###
# Check 'x11'/'wayland' Display Server Protocol
function check_dsp() {
    if [[ -n "$XDG_SESSION_TYPE" && "$XDG_SESSION_TYPE" == "wayland" ]]; then
        # Set GDK_BACKEND to 'x11' for 'yad' compatibility.
        export GDK_BACKEND=x11
    fi
}

# Check WinApps Configuration File Exists
function check_config_exists() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Throw an error.
        show_error_message "ERROR: WinApps configuration file <u>NOT FOUND</u>.\nPlease ensure <i>${CONFIG_FILE}</i> exists."
        exit "$EC_NO_WACONFIG"
    fi
}

# WinApps Flavor Detection
function winapps_flavor_detection() {
    # Read the WinApps configuration file line by line.
    while IFS= read -r LINE; do
        # Check if the line begins with 'WAFLAVOR='.
        if [[ "$LINE" == WAFLAVOR=\"* ]]; then
            # Extract the value.
            WAFLAVOR=$(echo "$LINE" | sed -n '/^WAFLAVOR="/s/^WAFLAVOR="\([^"]*\)".*/\1/p')
            echo -e "${DEBUG_TEXT}> USING BACKEND '${WAFLAVOR}'${RESET_TEXT}"
            break
        fi
    done < "$CONFIG_FILE"

    if [[ -z "$WAFLAVOR" ]]; then
        # Use the default WinApps flavor if it was not specified.
        WAFLAVOR="$DEFAULT_FLAVOR"
        echo -e "${DEBUG_TEXT}> USING DEFAULT BACKEND '${WAFLAVOR}'${RESET_TEXT}"
    else
        # Check if a valid flavor was specified.
#        if [[ "$WAFLAVOR" != "docker" && "$WAFLAVOR" != "podman" && "$WAFLAVOR" != "libvirt" ]]; then
         if [[ "$WAFLAVOR" != "docker" && "$WAFLAVOR" != "podman" && "$WAFLAVOR" != "libvirt" && "$WAFLAVOR" != "manual" ]]; then
            # Throw an error.
            show_error_message "ERROR: Specified WinApps backend '${WAFLAVOR}' <u>INVALID</u>.\nPlease ensure 'WAFLAVOR' is set to \"docker\", \"podman\" or \"libvirt\" within <i>${CONFIG_FILE}</i>."
            exit "$EC_BAD_BACKEND"
        fi
    fi
}

# Process Shutdown Handler
function on_exit() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> EXIT${RESET_TEXT}"

    # Clean Exit
    echo "quit" >&3
    rm -f "$PIPE"
}
trap on_exit EXIT

# Check FreeRDP Running
function check_freerdp_running() {
    if find "${APPDATA_PATH}" -maxdepth 1 -name 'FreeRDP_Process_*.cproc' -print -quit | grep -q .; then
        echo "YES"
    else
        echo "NO"
    fi
}
export -f check_freerdp_running

# Kill FreeRDP
function kill_freerdp() {
    # Declare variables.
    local TERMINATED_PROCESS_IDS=()
    local TERMINATED_PROCESS_IDS_STRING=""

    # Loop through each matching file and add to the array
    for FREERDP_PROCESS_FILE in "${APPDATA_PATH}/FreeRDP_Process_"*.cproc; do
        # This check ensures the pattern is not treated as a literal string if no files match the pattern.
        if [ -f "$FREERDP_PROCESS_FILE" ]; then
            # Extract the file name from the path.
            FREERDP_PROCESS_FILE=$(basename "$FREERDP_PROCESS_FILE")

            # Remove the 'FreeRDP_Process_' prefix.
            FREERDP_PROCESS_FILE="${FREERDP_PROCESS_FILE#FreeRDP_Process_}"

            # Remove the '.cproc' file extension.
            FREERDP_PROCESS_FILE="${FREERDP_PROCESS_FILE%.cproc}"

            # Terminate the process (SIGKILL).
            kill -9 "$FREERDP_PROCESS_FILE" &>/dev/null

            # Remove the file.
            # NOTE: This is not necessary as 'bin/winapps' will automatically delete the file once the process terminates.
            #rm "${APPDATA_PATH}/FreeRDP_Process_${FREERDP_PROCESS_FILE}.cproc" &>/dev/null

            # Print debug feedback.
            echo -e "${DEBUG_TEXT}> KILLED FREERDP PROCESS '${FREERDP_PROCESS_FILE}'${RESET_TEXT}"

            # Add the process ID to the list of terminated processes.
            TERMINATED_PROCESS_IDS+=("$FREERDP_PROCESS_FILE")
        fi
    done

    # Convert the array of process IDs to a comma-delimited string.
    TERMINATED_PROCESS_IDS_STRING=$(printf "%s, " "${TERMINATED_PROCESS_IDS[@]}" | sed 's/, $//')

    # Display feedback if any processes were terminated.
    [ ${#TERMINATED_PROCESS_IDS[@]} -ne 0 ] && show_error_message "<u>KILLED</u> FreeRDP process(es): ${TERMINATED_PROCESS_IDS_STRING}."
}
export -f kill_freerdp

# Error Message
function show_error_message() {
    local MESSAGE="${1}"

    yad --error \
        --fixed \
        --on-top \
        --skip-taskbar \
        --borders=15 \
        --window-icon=dialog-error \
        --selectable-labels \
        --title="WinApps Launcher" \
        --image=dialog-error \
        --text="$MESSAGE" \
        --button=yad-ok:0 \
        --timeout=10 \
        --timeout-indicator=bottom &
}
export -f show_error_message

# Application Selection
function app_select() {
    if check_reachable; then
        local ALL_FILES=()
        local APP_LIST=()
        local SORTED_APP_LIST=()
        local SORTED_APP_STRING=""
        local SELECTED_APP=""

        # Store the paths of all files within the directory 'WINAPPS_PATH'.
        readarray -t ALL_FILES < <(find "$WINAPPS_PATH" -maxdepth 1 -type f)

        # Ignore files that do not contain "${WINAPPS_PATH}/winapps".
        # Ignore files named "winapps" and "windows".
        for FILE in "${ALL_FILES[@]}"; do
            if grep -q "${WINAPPS_PATH}/winapps" "$FILE" && [ "$(basename "$FILE")" != "windows" ] && [ "$(basename "$FILE")" != "winapps" ]; then
                # Store the filename.
                FILENAME=$(basename "$FILE")

                # Store the application name.
                if [ -f "${USER_WINAPPS_APPLICATIONS}/${FILENAME}/info" ]; then
                    # WinApps 'User' Installation.
                    # Identify the 'FULL_NAME' line and extract the string within double quotes.
                    APPNAME=$(grep '^FULL_NAME=' "${USER_WINAPPS_APPLICATIONS}/${FILENAME}/info" | sed 's/^FULL_NAME="//;s/"$//')
                elif [ -f "${SYSTEM_WINAPPS_APPLICATIONS}/${FILENAME}/info" ]; then
                    # WinApps 'System' Installation.
                    # Identify the 'FULL_NAME' line and extract the string within double quotes.
                    APPNAME=$(grep '^FULL_NAME=' "${SYSTEM_WINAPPS_APPLICATIONS}/${FILENAME}/info" | sed 's/^FULL_NAME="//;s/"$//')
                else
                    # Set the application name as the file name.
                    APPNAME="$FILENAME"
                fi

                # Store names in arrays.
                APP_LIST+=("${APPNAME}:${FILENAME}")
            fi
        done

        # Sort applications in alphabetical order based on the application name.
        mapfile -t SORTED_APP_LIST < <(printf "%s\n" "${APP_LIST[@]}" | sort)

        # Convert the array to a colon-delimited string.
        SORTED_APP_STRING=""
        for APP in "${SORTED_APP_LIST[@]}"; do
            # Split entry into two parts based on the colon separator.
            IFS=':' read -r application_name file_name <<< "$APP"

            # Append formatted line to data string.
            SORTED_APP_STRING+="${application_name}\n"
            SORTED_APP_STRING+="${file_name}\n"
        done

        # Display application selection popup window.
        SELECTED_APP=$(echo -e "$SORTED_APP_STRING" | yad --list \
        --title="WinApps Launcher" \
        --width=300 \
        --height=500 \
        --text="Select Windows Application to Launch:" \
        --window-icon="${ICONS_PATH}/AppIcon.svg" \
        --hide-column=2 \
        --column="Application Name" \
        --column="File Name")

        if [ -n "$SELECTED_APP" ]; then
            # Remove Trailing Bar
            SELECTED_APP="${SELECTED_APP%|}"

            # Extract the file name.
            SELECTED_APP=$(echo "$SELECTED_APP" | cut -d'|' -f2)

            # Run Selected Application
            winapps "$SELECTED_APP" &>/dev/null &
            echo -e "${DEBUG_TEXT}> LAUNCHED '${SELECTED_APP}'${RESET_TEXT}"
        fi
    fi
}
export -f app_select

# Launch Windows
function launch_windows() {
    if check_reachable; then
        # Run Windows
        winapps windows &>/dev/null &
        echo -e "${DEBUG_TEXT}> LAUNCHED WINDOWS RDP SESSION${RESET_TEXT}"
    fi
}
export -f launch_windows

# Check Windows Exists
function check_windows_exists() {
    if [[ $WAFLAVOR == "libvirt" ]]; then
        # Check Virtual Machine State
        local WINSTATE=""
        WINSTATE=$(virsh domstate "$VM_NAME" 2>&1 | xargs)

        if grep -q "argument is empty" <<< "$WINSTATE"; then
            # Unspecified
            show_error_message "ERROR: Windows VM <u>NOT SPECIFIED</u>.\nPlease ensure a virtual machine name is specified."
            exit "$EC_WIN_NOT_SPEC"
        elif grep -q "failed to get domain" <<< "$WINSTATE"; then
            # Not Found
            show_error_message "ERROR: Windows VM <u>NOT FOUND</u>.\nPlease ensure <i>'${VM_NAME}'</i> exists."
            exit "$EC_NO_WIN_FOUND"
        fi
    elif [[ $WAFLAVOR == "podman" ]]; then
        if ! podman ps --all --filter name="WinApps" | grep -q "$CONTAINER_NAME"; then
            # Not Found
            show_error_message "ERROR: Podman container '${CONTAINER_NAME}' <u>NOT FOUND</u>.\nPlease ensure <i>'${CONTAINER_NAME}'</i> exists."
            exit "$EC_NO_WIN_FOUND"
        fi
    elif [[ $WAFLAVOR == "docker" ]]; then
        if ! docker ps --all --filter name="WinApps" | grep -q "$CONTAINER_NAME"; then
            # Not Found
            show_error_message "ERROR: Docker container '${CONTAINER_NAME}' <u>NOT FOUND</u>.\nPlease ensure <i>'${CONTAINER_NAME}'</i> exists."
            exit "$EC_NO_WIN_FOUND"
        fi
    fi
}
export -f check_windows_exists

# Check Reachable
function check_reachable() {
    # Only bother checking if Windows is reachable when using 'libvirt'.
    if [[ "$WAFLAVOR" == "libvirt" ]]; then
        #VM_IP=$(virsh net-dhcp-leases default | grep "${VM_NAME}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}') # Unreliable since this does not always list VM
        # shellcheck disable=SC2155 # Silence warning regarding declaring and assigning variables separately.
        local VM_MAC=$(virsh domiflist "$VM_NAME" | grep -Eo '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') # Virtual Machine MAC Address
        # shellcheck disable=SC2155 # Silence warning regarding declaring and assigning variables separately.
        local VM_IP=$(ip neigh show | grep "$VM_MAC" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}") # Virtual Machine IP Address

        if [ -z "$VM_IP" ]; then
            # Empty
            show_error_message "ERROR: Windows VM is <u>UNREACHABLE</u>.\nPlease ensure <i>'${VM_NAME}'</i> has an IP address."
            return 1
        else
            # Not Empty
            # Print Feedback
            echo -e "${ADDRESS_TEXT}# VM MAC ADDRESS: ${VM_MAC}${RESET_TEXT}"
            echo -e "${ADDRESS_TEXT}# VM IP ADDRESS: ${VM_IP}${RESET_TEXT}"
        fi
    fi
}
export -f check_reachable

function generate_menu() {
    local STATE=""


    if [[ "$WAFLAVOR" == "manual" ]]; then
        echo -e "${DEBUG_TEXT}> SKIPPING VM CONTROL IN 'manual' MODE${RESET_TEXT}"
            echo "menu:\
      ${MENU_APPLICATIONS}|\
      ${MENU_REDMOND}|\
      ${MENU_KILL}|\
      ${MENU_REFRESH}|\
      ${MENU_QUIT}" >&3
          return
    fi
    # Check Windows State
    if [[ "$WAFLAVOR" == "libvirt" ]]; then
        # Possible values are 'running', 'paused' and 'shut off'.
        STATE=$(virsh domstate "$VM_NAME" 2>&1 | xargs)

        # Map state to standard terminology.
        if [[ "$STATE" == "running" ]]; then
            STATE="ON"
        elif [[ "$STATE" == "paused" ]]; then
            STATE="PAUSED"
        elif [[ "$STATE" == "shut off" ]]; then
            STATE="OFF"
        fi
    elif [[ "$WAFLAVOR" == "podman" ]]; then
        # Possible values are 'created', 'up', 'paused', 'stopping' and 'exited'.
        STATE=$(podman ps --all --filter name="$CONTAINER_NAME" --format '{{.Status}}')
        STATE=${STATE,,} # Convert the string to lowercase.
        STATE=${STATE%% *} # Extract the first word.

        # Map state to standard terminology.
        if [[ "$STATE" == "up" ]] || [[ "$STATE" == "stopping" ]]; then
            STATE="ON"
        elif [[ "$STATE" == "paused" ]]; then
            STATE="PAUSED"
        elif [[ "$STATE" == "exited" ]] || [[ "$STATE" == "created" ]]; then
            STATE="OFF"
        fi
    elif [[ "$WAFLAVOR" == "docker" ]]; then
        # Possible values are 'created', 'restarting', 'up', 'paused' and 'exited'.
        STATE=$(docker ps --all --filter name="$CONTAINER_NAME" --format '{{.Status}}')
        STATE=${STATE,,} # Convert the string to lowercase.
        STATE=${STATE%% *} # Extract the first word.

        # Map state to standard terminology.
        if [[ "$STATE" == "up" ]] || [[ "$STATE" == "restarting" ]]; then
            STATE="ON"
        elif [[ "$STATE" == "paused" ]]; then
            STATE="PAUSED"
        elif [[ "$STATE" == "exited" ]] || [[ "$STATE" == "created" ]]; then
            STATE="OFF"
        fi
    fi

    # Print Feedback
    echo -e "${STATUS_TEXT}* VM STATE: ${STATE}${RESET_TEXT}"

    case "$STATE" in
        "ON")
            echo "menu:\
${MENU_APPLICATIONS}|\
${MENU_REDMOND}|\
${MENU_PAUSE}|\
${MENU_HIBERNATE}|\
${MENU_POWEROFF}|\
${MENU_REBOOT}|\
${MENU_FORCEOFF}|\
${MENU_RESET}|\
${MENU_KILL}|\
${MENU_REFRESH}|\
${MENU_QUIT}" >&3
            ;;
        "PAUSED")
            echo "menu:\
${MENU_RESUME}|\
${MENU_HIBERNATE}|\
${MENU_POWEROFF}|\
${MENU_REBOOT}|\
${MENU_FORCEOFF}|\
${MENU_RESET}|\
${MENU_KILL}|\
${MENU_REFRESH}|\
${MENU_QUIT}" >&3
            ;;
        "OFF")
            echo "menu:\
${MENU_POWERON}|\
${MENU_KILL}|\
${MENU_REFRESH}|\
${MENU_QUIT}" >&3
            ;;
    esac
}
export -f generate_menu

# Start Windows
function start_windows() {

    if [[ "$WAFLAVOR" == "manual" ]]; then
        echo -e "${DEBUG_TEXT}> SKIPPING VM CONTROL IN 'manual' MODE${RESET_TEXT}"
        return
    fi
    # Issue Command
    if [[ "$WAFLAVOR" == "libvirt" ]]; then
        virsh start "$VM_NAME" &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> STARTED '${VM_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "podman" ]]; then
        podman-compose --file "$COMPOSE_FILE" start &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> STARTED '${CONTAINER_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "docker" ]]; then
        docker compose --file "$COMPOSE_FILE" start &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> STARTED '${CONTAINER_NAME}'${RESET_TEXT}"
    fi

    # Reopen PIPE
    exec 3<> "$PIPE"

    # Refresh Menu
    generate_menu
}
export -f start_windows

# Stop Windows
function stop_windows() {
    if [[ "$(check_freerdp_running)" == "YES" ]]; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Powering Off Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        if [[ "$WAFLAVOR" == "libvirt" ]]; then
            virsh shutdown "$VM_NAME" &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> POWERED OFF '${VM_NAME}'${RESET_TEXT}"
        elif [[ "$WAFLAVOR" == "podman" ]]; then
            podman-compose --file "$COMPOSE_FILE" stop &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> POWERED OFF '${CONTAINER_NAME}'${RESET_TEXT}"
        elif [[ "$WAFLAVOR" == "docker" ]]; then
            docker compose --file "$COMPOSE_FILE" stop &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> POWERED OFF '${CONTAINER_NAME}'${RESET_TEXT}"
        fi

        # Reopen PIPE
        exec 3<> "$PIPE"

        # Refresh Menu
        generate_menu
    fi
}
export -f stop_windows

# Pause Windows
function pause_windows() {
    if [[ "$(check_freerdp_running)" == "YES" ]]; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Pausing Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        if [[ "$WAFLAVOR" == "libvirt" ]]; then
            virsh suspend "$VM_NAME" &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> PAUSED '${VM_NAME}'${RESET_TEXT}"
        elif [[ "$WAFLAVOR" == "podman" ]]; then
            podman-compose --file "$COMPOSE_FILE" pause &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> PAUSED '${CONTAINER_NAME}'${RESET_TEXT}"
        elif [[ "$WAFLAVOR" == "docker" ]]; then
            docker compose --file "$COMPOSE_FILE" pause &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> PAUSED '${CONTAINER_NAME}'${RESET_TEXT}"
        fi

        # Reopen PIPE
        exec 3<> "$PIPE"

        # Refresh Menu
        generate_menu
    fi
}
export -f pause_windows

# Resume Windows
function resume_windows() {
    # Issue Command
    if [[ "$WAFLAVOR" == "libvirt" ]]; then
        virsh resume "$VM_NAME" &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> RESUMED '${VM_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "podman" ]]; then
        podman-compose --file "$COMPOSE_FILE" unpause &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> RESUMED '${CONTAINER_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "docker" ]]; then
        docker compose --file "$COMPOSE_FILE" unpause &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> RESUMED '${CONTAINER_NAME}'${RESET_TEXT}"
    fi

    # Reopen PIPE
    exec 3<> "$PIPE"

    # Refresh Menu
    generate_menu
}
export -f resume_windows

# Reset Windows
function reset_windows() {
    # Issue Command
    if [[ "$WAFLAVOR" == "libvirt" ]]; then
        virsh reset "$VM_NAME" &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> RESET '${VM_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "podman" ]]; then
        podman-compose --file "$COMPOSE_FILE" kill &>/dev/null &
        wait $!
        podman-compose --file "$COMPOSE_FILE" start &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> RESET '${CONTAINER_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "docker" ]]; then
        docker compose --file "$COMPOSE_FILE" kill &>/dev/null &
        wait $!
        docker compose --file "$COMPOSE_FILE" start &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> RESET '${CONTAINER_NAME}'${RESET_TEXT}"
    fi

    # Reopen PIPE
    exec 3<> "$PIPE"

    # Refresh Menu
    generate_menu
}
export -f reset_windows

# Reboot Windows
function reboot_windows() {
    if [[ "$(check_freerdp_running)" == "YES" ]]; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Rebooting Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        if [[ "$WAFLAVOR" == "libvirt" ]]; then
            virsh reboot "$VM_NAME" &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> RESTARTED '${VM_NAME}'${RESET_TEXT}"
        elif [[ "$WAFLAVOR" == "podman" ]]; then
            podman-compose --file "$COMPOSE_FILE" restart &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> RESTARTED '${CONTAINER_NAME}'${RESET_TEXT}"
        elif [[ "$WAFLAVOR" == "docker" ]]; then
            docker compose --file "$COMPOSE_FILE" restart &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> RESTARTED '${CONTAINER_NAME}'${RESET_TEXT}"
        fi

        # Reopen PIPE
        exec 3<> "$PIPE"

        # Refresh Menu
        generate_menu
    fi
}
export -f reboot_windows

# Force Stop Windows
function force_stop_windows() {
    # Issue Command
    if [[ "$WAFLAVOR" == "libvirt" ]]; then
        virsh destroy "$VM_NAME" --graceful &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> FORCE STOPPED '${VM_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "podman" ]]; then
        podman-compose --file "$COMPOSE_FILE" kill &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> FORCE STOPPED '${CONTAINER_NAME}'${RESET_TEXT}"
    elif [[ "$WAFLAVOR" == "docker" ]]; then
        docker compose --file "$COMPOSE_FILE" kill &>/dev/null &
        wait $!
        echo -e "${DEBUG_TEXT}> FORCE STOPPED '${CONTAINER_NAME}'${RESET_TEXT}"
    fi

    # Reopen PIPE
    exec 3<> "$PIPE"

    # Refresh Menu
    generate_menu
}
export -f force_stop_windows

# Hibernate Windows
function hibernate_windows() {
    if [[ "$(check_freerdp_running)" == "YES" ]]; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Hibernating Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        if [[ "$WAFLAVOR" == "libvirt" ]]; then
            virsh managedsave "$VM_NAME" &>/dev/null &
            wait $!
            echo -e "${DEBUG_TEXT}> HIBERNATED '${VM_NAME}'${RESET_TEXT}"

            # Reopen PIPE
            exec 3<> "$PIPE"

            # Refresh Menu
            generate_menu
        else
            # Throw an error.
            show_error_message "ERROR: Hibernation is <u>NOT SUPPORTED</u> with the current configuration.\nTo enable hibernation, please use 'libvirt' instead of 'Docker' or 'Podman'."
        fi
    fi
}
export -f hibernate_windows

# Refresh Menu
function refresh_menu() {
    # Reopen PIPE
    exec 3<> "$PIPE"

    # Refresh Menu
    generate_menu

    # Print Feedback
    echo -e "${DEBUG_TEXT}> REFRESHED MENU${RESET_TEXT}"
}
export -f refresh_menu

### SEQUENTIAL LOGIC ###
# Check display server protocol.
check_dsp

# Check 'DISPLAY' variable.
[ -n "$DISPLAY" ] || exit "$EC_DSPLY_UNSET"

# SET WORKING DIRECTORY.
if cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"; then
    # Print Feedback
    echo -e "${PATH_TEXT}WORKING DIRECTORY: '$(pwd)'${RESET_TEXT}"
else
    echo -e "${ERROR_TEXT}ERROR:${RESET_TEXT} Failed to change directory to the script location."
    exit "$EC_CDIR_FAILED"
fi

# SET FIFO FILE & FILE DESCRIPTOR.
# shellcheck disable=SC2155 # Silence warning regarding declaring and assigning variables separately.
export PIPE=$(mktemp -u --tmpdir "${0##*/}".XXXXXXXX)
mkfifo "$PIPE"
exec 3<> "$PIPE"

# CHECK DEPENDENCIES.
# 'yad'
if ! command -v yad &> /dev/null; then
    echo -e "${ERROR_TEXT}ERROR:${RESET_TEXT} 'yad' not installed."
    exit "$EC_MISSING_DEP"
fi

# 'libvirt'
if [[ "$WAFLAVOR" == "libvirt" ]]; then
    if ! command -v virsh &> /dev/null; then
        show_error_message "ERROR: 'libvirt' <u>NOT FOUND</u>.\nPlease ensure 'libvirt' is installed."
        exit "$EC_MISSING_DEP"
    fi
fi

# 'winapps'
if ! command -v winapps &> /dev/null; then
    show_error_message "ERROR: 'winapps' <u>NOT FOUND</u>.\nPlease ensure 'winapps' is installed."
    exit "$EC_MISSING_DEP"
else
    WINAPPS_PATH=$(dirname "$(which winapps)")
fi

# INITIALISATION.
check_config_exists
winapps_flavor_detection
check_windows_exists
generate_menu

# TOOLBAR NOTIFICATION.
yad --notification \
    --listen \
    --no-middle \
    --text="WinApps Launcher" \
    --image="${ICONS_PATH}/AppIcon.svg" \
    --command="menu" <&3
