#!/usr/bin/env bash

### GLOBAL CONSTANTS ###
# ANSI Escape Sequences
export readonly ERROR_TEXT="\033[1;31m"
export readonly DEBUG_TEXT="\033[1;33m"
export readonly STATUS_TEXT="\033[1;32m"
export readonly ADDRESS_TEXT="\033[1;34m"
export readonly COMMAND_TEXT="\033[0;37m"
export readonly PATH_TEXT="\033[1;35m"
export readonly RESET_TEXT="\033[0m"

# Paths
export readonly ICONS_PATH="./Icons"

# Menu Entries
export readonly MENU_APPLICATIONS="Applications!bash -c app_select!${ICONS_PATH}/Applications.svg"
export readonly MENU_FORCEOFF="Force Power Off!bash -c force_power_off_vm!${ICONS_PATH}/ForceOff.svg"
export readonly MENU_KILL="Kill FreeRDP!bash -c kill_xfreerdp!${ICONS_PATH}/Kill.svg"
export readonly MENU_PAUSE="Pause!bash -c pause_vm!${ICONS_PATH}/Pause.svg"
export readonly MENU_POWEROFF="Power Off!bash -c power_off_vm!${ICONS_PATH}/Power.svg"
export readonly MENU_POWERON="Power On!bash -c power_on_vm!${ICONS_PATH}/Power.svg"
export readonly MENU_QUIT="Quit!quit!${ICONS_PATH}/Quit.svg"
export readonly MENU_REBOOT="Reboot!bash -c reboot_vm!${ICONS_PATH}/Reboot.svg"
export readonly MENU_REDMOND="Windows!bash -c launch_windows!${ICONS_PATH}/Redmond.svg"
export readonly MENU_REFRESH="Refresh Menu!bash -c refresh_menu!${ICONS_PATH}/Refresh.svg"
export readonly MENU_RESET="Reset!bash -c reset_vm!${ICONS_PATH}/Reset.svg"
export readonly MENU_RESUME="Resume!bash -c resume_vm!${ICONS_PATH}/Resume.svg"
export readonly MENU_HIBERNATE="Hibernate!bash -c hibernate_vm!${ICONS_PATH}/Hibernate.svg"

# Other
export readonly VM_NAME="RDPWindows"
export readonly RDP_COMMAND="xfreerdp"
export readonly SLEEP_DURATION="1.5"

### GLOBAL VARIABLES ###
export WINAPPS_PATH=""    # Generated programmatically following dependency checks.

### WORKING DIRECTORY ###
if cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"; then
    # Print Feedback
    echo -e "${PATH_TEXT}WORKING DIRECTORY: '$(pwd)'${RESET_TEXT}"
else
    echo -e "${ERROR_TEXT}ERROR:${RESET_TEXT} Failed to change directory to the script location."
    exit 1
fi

### FIFO FILE & FILE DESCRIPTOR ###
export PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE
exec 3<> $PIPE

### FUNCTIONS ###
# Process Shutdown Handler
function on_exit() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> EXIT${RESET_TEXT}"

    # Clean Exit
    echo "quit" >&3
    rm -f $PIPE
}
trap on_exit EXIT

# Kill FreeRDP
kill_xfreerdp() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> KILL FREERDP PROCESSES${RESET_TEXT}"

    # Find all FreeRDP processes
    local pids=$(pgrep $RDP_COMMAND)

    # Check if any processes were found
    if [ -n "$pids" ]; then
        echo -e "${COMMAND_TEXT}% $(echo "$pids" | xargs kill -9)${RESET_TEXT}"
        show_error_message "<u>KILLED</u> FreeRDP (${RDP_COMMAND}) process(es): ${pids}."
    fi
}
export -f kill_xfreerdp

# Error Message
show_error_message() {
    local message="${1}"

    yad --error \
        --fixed \
        --on-top \
        --skip-taskbar \
        --borders=15 \
        --window-icon=dialog-error \
        --selectable-labels \
        --title="WinApps Launcher" \
        --image=dialog-error \
        --text="$message" \
        --button=yad-ok:0 \
        --timeout=10 \
        --timeout-indicator=bottom &
}
export -f show_error_message

# Application Selection
app_select() {
    if check_reachable; then
        local APP_LIST=()

        # Store the filenames of files containing "${WINAPPS_PATH}/winapps" in an array.
        # Ignore files named "winapps" and "windows".
        # Return an empty array if no such files exist.
        readarray -t APP_LIST < <(find "$WINAPPS_PATH" -maxdepth 1 -type f ! -name "winapps" ! -name "windows" -exec grep -l "${WINAPPS_PATH}/winapps" {} + 2>/dev/null | xargs -I {} basename {})

        local selected_app=$(yad --list \
        --title="WinApps Launcher" \
        --width=300 \
        --height=500 \
        --text="Select Windows Application to Launch:" \
        --window-icon="${ICONS_PATH}/AppIcon.svg" \
        --column="Application Name" \
        "${APP_LIST[@]}")

        if [ -n "${selected_app}" ]; then
            # Remove Trailing Bar
            selected_app=$(echo $selected_app | cut -d"|" -f1)

            # Print Feedback
            echo -e "${DEBUG_TEXT}> LAUNCH '$selected_app'${RESET_TEXT}"

            # Run Selected Application
            winapps $selected_app
        fi
    fi
}
export -f app_select

# Launch Windows
function launch_windows() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> LAUNCH WINDOWS${RESET_TEXT}"

    if check_reachable; then
        # Run Windows
        winapps windows
    fi
}
export -f launch_windows

# Check Valid Domain
check_valid_domain() {
    # Check Virtual Machine State
    VM_STATE=$(virsh domstate "${VM_NAME}" 2>&1 | xargs)

    if grep -q "argument is empty" <<< "${VM_STATE}"; then
        # Unspecified Domain
        show_error_message "ERROR: Windows VM <u>NOT SPECIFIED</u>.\nPlease ensure a virtual machine name is specified."
        exit 3
    elif grep -q "failed to get domain" <<< "${VM_STATE}"; then
        # Domain Not Found
        show_error_message "ERROR: Windows VM <u>NOT FOUND</u>.\nPlease ensure <i>'${VM_NAME}'</i> exists."
        exit 4
    fi
}
export -f check_valid_domain

# Check Reachable
check_reachable() {
    #VM_IP=$(virsh net-dhcp-leases default | grep "${VM_NAME}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}') # Unreliable since this does not always list VM
    local VM_MAC=$(virsh domiflist "${VM_NAME}" | grep -Eo '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') # Virtual Machine MAC Address
    local VM_IP=$(arp -n | grep "${VM_MAC}" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}") # Virtual Machine IP Address

    if [ -z "${VM_IP}" ]; then
        # Empty
        show_error_message "ERROR: Windows VM is <u>UNREACHABLE</u>.\nPlease ensure <i>'${VM_NAME}'</i> has an IP address."
        return 1
    else
        # Not Empty
        # Print Feedback
        echo -e "${ADDRESS_TEXT}# VM MAC ADDRESS: ${VM_MAC}${RESET_TEXT}"
        echo -e "${ADDRESS_TEXT}# VM IP ADDRESS: ${VM_IP}${RESET_TEXT}"
        return 0
    fi
}
export -f check_reachable

generate_menu() {
    # Check Virtual Machine State
    VM_STATE=$(virsh domstate "${VM_NAME}" 2>&1 | xargs)

    # Print Feedback
    echo -e "${STATUS_TEXT}* VM STATE: ${VM_STATE^^}${RESET_TEXT}"

    if [ "${VM_STATE}" = "running" ]; then
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
    elif [ "${VM_STATE}" = "paused" ]; then
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
    elif [ "${VM_STATE}" = "shut off" ]; then
        echo "menu:\
${MENU_POWERON}|\
${MENU_KILL}|\
${MENU_REFRESH}|\
${MENU_QUIT}" >&3
    fi
}
export -f generate_menu

# Power On VM
function power_on_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> POWER ON VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    # Issue Command
    echo -e "${COMMAND_TEXT}% $(virsh start $VM_NAME | grep -v "^$")${RESET_TEXT}"
    sleep $SLEEP_DURATION

    # Refresh Menu
    generate_menu
}
export -f power_on_vm

# Power Off VM
function power_off_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> POWER OFF VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    if pgrep -x $RDP_COMMAND > /dev/null; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Powering Off Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        echo -e "${COMMAND_TEXT}% $(virsh shutdown $VM_NAME | grep -v "^$")${RESET_TEXT}"
        sleep $SLEEP_DURATION

        # Refresh Menu
        generate_menu
    fi
}
export -f power_off_vm

# Pause VM
function pause_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> PAUSE VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    if pgrep -x $RDP_COMMAND > /dev/null; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Pausing Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        echo -e "${COMMAND_TEXT}% $(virsh suspend $VM_NAME | grep -v "^$")${RESET_TEXT}"
        sleep $SLEEP_DURATION

        # Refresh Menu
        generate_menu
    fi
}
export -f pause_vm

# Resume VM
function resume_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> RESUME VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    # Issue Command
    echo -e "${COMMAND_TEXT}% $(virsh resume $VM_NAME | grep -v "^$")${RESET_TEXT}"
    sleep $SLEEP_DURATION

    # Refresh Menu
    generate_menu
}
export -f resume_vm

# Reset VM
function reset_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> RESET VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    # Issue Command
    echo -e "${COMMAND_TEXT}% $(virsh reset $VM_NAME | grep -v "^$")${RESET_TEXT}"
    sleep $SLEEP_DURATION

    # Refresh Menu
    generate_menu
}
export -f reset_vm

# Reboot VM
function reboot_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> REBOOT VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    if pgrep -x $RDP_COMMAND > /dev/null; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Rebooting Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        echo -e "${COMMAND_TEXT}% $(virsh reboot $VM_NAME | grep -v "^$")${RESET_TEXT}"
        sleep $SLEEP_DURATION

        # Refresh Menu
        generate_menu
    fi
}
export -f reboot_vm

# Force Power Off VM
function force_power_off_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> FORCE POWER OFF VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    # Issue Command
    echo -e "${COMMAND_TEXT}% $(virsh destroy $VM_NAME --graceful | grep -v "^$")${RESET_TEXT}"
    sleep $SLEEP_DURATION

    # Refresh Menu
    generate_menu
}
export -f force_power_off_vm

# Save VM
function hibernate_vm() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> HIBERNATE VM${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE
    if pgrep -x $RDP_COMMAND > /dev/null; then
        # FreeRDP Sessions Running
        show_error_message "ERROR: Hibernating Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        # Issue Command
        echo -e "${COMMAND_TEXT}% $(virsh managedsave $VM_NAME | grep -v "^$")${RESET_TEXT}"
        sleep $SLEEP_DURATION

        # Refresh Menu
        generate_menu
    fi
}
export -f hibernate_vm

# Refresh Menu
function refresh_menu() {
    # Print Feedback
    echo -e "${DEBUG_TEXT}> REFRESH MENU${RESET_TEXT}"

    # Reopen PIPE
    exec 3<> $PIPE

    # Refresh Menu
    generate_menu
}
export -f refresh_menu

### CHECK DEPENDENCIES ###
# 'yad'
if ! command -v yad &> /dev/null; then
    echo -e "${ERROR_TEXT}ERROR:${RESET_TEXT} 'yad' not installed."
    exit 2
fi

# 'libvirt'
if ! command -v virsh &> /dev/null; then
    show_error_message "ERROR: 'libvirt' <u>NOT FOUND</u>.\nPlease ensure 'libvirt' is installed."
    exit 2
fi

# 'winapps'
if ! command -v winapps &> /dev/null; then
    show_error_message "ERROR: 'winapps' <u>NOT FOUND</u>.\nPlease ensure 'winapps' is installed."
    exit 2
else
    WINAPPS_PATH=$(dirname $(which winapps))
fi

### INITIALISATION ###
check_valid_domain
generate_menu

### TOOLBAR NOTIFICATION ###
yad --notification \
    --listen \
    --no-middle \
    --text="WinApps Launcher" \
    --image="${ICONS_PATH}/AppIcon.svg" \
    --command="menu" \
    --menu="\
${MENU_APPLICATIONS}|\
${MENU_REDMOND}|\
${MENU_POWERON}|\
${MENU_PAUSE}|\
${MENU_RESUME}|\
${MENU_HIBERNATE}|\
${MENU_POWEROFF}|\
${MENU_REBOOT}|\
${MENU_FORCEOFF}|\
${MENU_RESET}|\
${MENU_KILL}|\
${MENU_REFRESH}|\
${MENU_QUIT}" <&3
