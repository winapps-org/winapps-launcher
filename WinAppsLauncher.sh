#!/bin/bash
# ### CONSTANTS ###
export readonly VM_NAME="RDPWindows" # Virtual Machine Name
export readonly RDP_COMMAND="xfreerdp" # FreeRDP Command
export readonly WINAPPS_PATH="/usr/local/bin" # WinApps Install Path

# ### FIFO FILE & FILE DESCRIPTOR ###
export PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE
exec 3<> $PIPE

### CHECK DEPENDENCIES ###
# 'yad'
if ! command -v yad &> /dev/null; then
    echo "ERROR: 'yad' not installed. Exiting."
    exit 1
fi

# 'libvirt'
if ! command -v virsh &> /dev/null; then
    echo "ERROR: 'libvirt' not installed. Exiting."
    exit 1
fi

### FUNCTIONS ###
# Process Shutdown Handler
function on_exit() {
    echo "EXITING"
    echo "quit" >&3
    rm -f $PIPE
}
trap on_exit EXIT

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
        --title="WinApps" \
        --image=dialog-error \
        --text="$message" \
        --button=yad-ok:0 \
        --timeout=10 \
        --timeout-indicator=bottom &
}
export -f show_error_message

# Application Selection
app_select() {
    local selected_app=$(yad --list \
    --title="WinApps" \
    --width=300 \
    --height=500 \
    --text="Select Windows Application to Launch:" \
    --column="Application Name" \
    $(ls $WINAPPS_PATH | grep -v -E "^(winapps|windows)$"))

    # Remove Trailing Bar
    selected_app=$(echo $selected_app | cut -d"|" -f1)

    echo "SELECTED APPLICATION '$selected_app'"

    # Run Selected Application
    $WINAPPS_PATH/winapps $selected_app %F
}
export -f app_select

# Check Valid Domain
check_valid_domain() {
    VM_STATE=$(virsh domstate "${VM_NAME}" 2>&1 | xargs) # Virtual Machine State

    if grep -q "argument is empty" <<< "${VM_STATE}"; then
        # Unspecified Domain
        show_error_message "ERROR: Windows VM <u>NOT SPECIFIED</u>.\nPlease ensure a virtual machine name is specified."
        exit 2
    elif grep -q "failed to get domain" <<< "${VM_STATE}"; then
        # Domain Not Found
        show_error_message "ERROR: Windows VM <u>NOT FOUND</u>.\nPlease ensure <i>'${VM_NAME}'</i> exists."
        exit 3
    fi
}
export -f check_valid_domain

generate_menu() {
    VM_STATE=$(virsh domstate "${VM_NAME}" 2>&1 | xargs) # Virtual Machine State

    if [ "${VM_STATE}" = "running" ]; then
        echo "menu:\
Applications!bash -c app_select!window-new|\
Windows!bash -c launch_windows!web-microsoft|\
Pause!bash -c pause_vm!media-playback-pause|\
Save!bash -c save_vm!system-suspend|\
Power Off!bash -c power_off_vm!system-shutdown|\
Reboot!bash -c reboot_vm!system-reboot|\
Force Power Off!bash -c force_power_off_vm!process-stop|\
Reset!bash -c reset_vm!view-refresh|\
Refresh Menu!bash -c refresh_menu!edit-clear-all|\
Quit!quit!application-exit" >&3
    elif [ "${VM_STATE}" = "paused" ]; then
        echo "menu:\
Resume!bash -c resume_vm!media-playback-start|\
Save!bash -c save_vm!system-suspend|\
Power Off!bash -c power_off_vm!system-shutdown|\
Reboot!bash -c reboot_vm!system-reboot|\
Force Power Off!bash -c force_power_off_vm!process-stop|\
Reset!bash -c reset_vm!view-refresh|\
Refresh Menu!bash -c refresh_menu!edit-clear-all|\
Quit!quit!application-exit" >&3
    elif [ "${VM_STATE}" = "shut off" ]; then
        echo "menu:\
Power On!bash -c power_on_vm!gtk-yes|\
Refresh Menu!bash -c refresh_menu!edit-clear-all|\
Quit!quit!application-exit" >&3
    fi
}
export -f generate_menu

# Power On VM
function power_on_vm() {
    echo "POWER ON"
    exec 3<> $PIPE # Reopen PIPE
    virsh start $VM_NAME
    sleep 1
    generate_menu
}
export -f power_on_vm

# Power Off VM
function power_off_vm() {
    echo "POWER OFF"
    exec 3<> $PIPE # Reopen PIPE
    if pgrep -x $RDP_COMMAND > /dev/null; then
        show_error_message "ERROR: Powering Off Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        virsh shutdown $VM_NAME
        sleep 1
        generate_menu
    fi
}
export -f power_off_vm

# Pause VM
function pause_vm() {
    echo "PAUSE"
    exec 3<> $PIPE # Reopen PIPE
    if pgrep -x $RDP_COMMAND > /dev/null; then
        show_error_message "ERROR: Pausing Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        virsh suspend $VM_NAME
        sleep 1
        generate_menu
    fi
}
export -f pause_vm

# Resume VM
function resume_vm() {
    echo "RESUME"
    exec 3<> $PIPE # Reopen PIPE
    virsh resume $VM_NAME
    sleep 1
    generate_menu
}
export -f resume_vm

# Reset VM
function reset_vm() {
    echo "RESET"
    exec 3<> $PIPE # Reopen PIPE
    virsh reset $VM_NAME
    sleep 1
    generate_menu
}
export -f reset_vm

# Reboot VM
function reboot_vm() {
    echo "REBOOT"
    exec 3<> $PIPE # Reopen PIPE
    if pgrep -x $RDP_COMMAND > /dev/null; then
        show_error_message "ERROR: Rebooting Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        virsh reboot $VM_NAME
        sleep 1
        generate_menu
    fi
}
export -f reboot_vm

# Force Power Off VM
function force_power_off_vm() {
    echo "FORCE POWER OFF"
    exec 3<> $PIPE # Reopen PIPE
    virsh destroy $VM_NAME --graceful
    sleep 1
    generate_menu
}
export -f force_power_off_vm

# Save VM
function save_vm() {
    echo "SAVE"
    exec 3<> $PIPE # Reopen PIPE
    if pgrep -x $RDP_COMMAND > /dev/null; then
        show_error_message "ERROR: Saving Windows VM <u>FAILED</u>.\nPlease ensure all FreeRDP instance(s) are terminated."
    else
        virsh managedsave $VM_NAME
        sleep 1
        generate_menu
    fi
}
export -f save_vm

# Refresh Menu
function refresh_menu() {
    echo "REFRESH MENU"
    exec 3<> $PIPE # Reopen PIPE
    generate_menu
}
export -f refresh_menu

# Launch Windows
function launch_windows() {
    echo "LAUNCH WINDOWS"

    #VM_IP=$(virsh net-dhcp-leases default | grep "${VM_NAME}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}') # Unreliable since this does not always list VM
    local VM_MAC=$(virsh domiflist "${VM_NAME}" | grep -Eo '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') # Virtual Machine MAC Address
    local VM_IP=$(arp -n | grep "${VM_MAC}" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}") # Virtual Machine IP Address

    if ! [ -z "$VM_IP" ]; then
        # Run FreeRDP
        winapps windows
    else
        # No Connection
        show_error_message "ERROR: Windows VM is <u>UNREACHABLE</u>.\nPlease ensure <i>'${VM_NAME}'</i> has an IP address."
        exit 2
    fi
}
export -f launch_windows

### INITIALISATION ###
check_valid_domain
generate_menu

### TOOLBAR NOTIFICATION ###
yad --notification \
    --listen \
    --no-middle \
    --text="WinApps" \
    --image="web-microsoft" \
    --command="menu" \
    --menu="\
Applications!bash -c app_select!window-new|\
Windows!bash -c launch_windows!web-microsoft|\
Power On!bash -c power_on_vm!gtk-yes|\
Pause!bash -c pause_vm!media-playback-pause|\
Resume!bash -c resume_vm!media-playback-start|\
Save!bash -c save_vm!system-suspend|\
Power Off!bash -c power_off_vm!system-shutdown|\
Reboot!bash -c reboot_vm!system-reboot|\
Force Power Off!bash -c force_power_off_vm!process-stop|\
Reset!bash -c reset_vm!view-refresh|\
Refresh Menu!bash -c refresh_menu!edit-clear-all|\
Quit!quit!application-exit" <&3
