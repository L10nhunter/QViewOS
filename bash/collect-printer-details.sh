#!/bin/bash
max() {
    local max=0
    num
    for num in "$@"; do
        if ((num > max)); then
            max=$num
        fi
    done
    echo "$max"
}
min() {
    local min=99999
    num
    for num in "$@"; do
        if ((num < min)); then
            min=$num
        fi
    done
    echo "$min"
}
user_cancel() {
    echo "User cancelled input"
    exit 1
}

ENV_FILE="${CAM_DIR}/.env"

echo "Collecting printer and camera details..."

# Check if .env file already exists
if [[ -f "$ENV_FILE" ]]; then
    if whiptail --yesno --title \
        "Error: .env already exists!!!" ".env file already exists. Do you want to remove it and rerun the script?" \
        "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" \
        3>&1 1>&2 2>&3; then
        rm "$ENV_FILE"
    else
        echo "Exiting script."
        exit 1
    fi
fi
# Prompt for printer and camera details
PRINTER_ADDRESS="192.168.0.100"                                                                          # Default value
PRUSA_CONNECT_CAMERA_TOKEN="check-Prusa-Connect-Token"                                                   # Default value
CAMERA_COMMAND="rpicam-still"                                                                            # Default value
EXTRA_PARAMS='--immediate --nopreview --mode 4608:2592 --lores-width 0 --lores-height 0 --thumb none -o' # Default value
PADDING=24

# Collect inputs using Whiptail
while true; do
    # calculate the width of the longest menu item
    MENU_WIDTH=$(max $((${#EXTRA_PARAMS} + PADDING)) \
        $((${#CAMERA_COMMAND} + PADDING)) \
        $((${#PRINTER_ADDRESS} + PADDING)) \
        $((${#PRUSA_CONNECT_CAMERA_TOKEN} + PADDING)))
    MENU_HEIGHT=$(tput lines)
    # Show the menu
    CHOICE=$(whiptail --title "Printer & Camera Setup" --notags --ok-button "Select Option" --menu \
        "Select an option to edit, then choose 'Submit and Continue' to finish." \
        "$(min 20 "$MENU_HEIGHT")" "$MENU_WIDTH" 5 \
        "1" "Printer Address     : $PRINTER_ADDRESS" \
        "2" "Camera Token        : $PRUSA_CONNECT_CAMERA_TOKEN" \
        "3" "Camera Command      : $CAMERA_COMMAND" \
        "4" "Extra Params        : $EXTRA_PARAMS" \
        "5" "Submit and Continue" \
        3>&1 1>&2 2>&3) || user_cancel

    case "$CHOICE" in
    "1")
        while true; do
            # store old value in case of cancel
            OLD_PRINTER_ADDRESS="$PRINTER_ADDRESS"
            PRINTER_ADDRESS="$(whiptail --inputbox "Enter Printer Address (IPv4):" \
                "$(min 10 "$MENU_HEIGHT")" \
                "$(min 60 "$MENU_WIDTH")" \
                "$PRINTER_ADDRESS" 3>&1 1>&2 2>&3)" ||
                PRINTER_ADDRESS=$OLD_PRINTER_ADDRESS

            # Validate IPv4 format
            if [[ ! "$PRINTER_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                whiptail --msgbox "Invalid IPv4 format! Please enter a valid IPv4 address." \
                    "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")"
                continue
            fi
            # Check if each octet is between 0-255
            IFS='.' read -r o1 o2 o3 o4 <<<"$PRINTER_ADDRESS"
            if ((o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255)); then
                whiptail --msgbox "Invalid IPv4 address! Each octet must be between 0 and 255." \
                    "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")"
                continue
            fi

            break # Valid IPv4, exit loop
        done

        ;;
    "2")
        # store old value in case of cancel
        OLD_PRUSA_CONNECT_CAMERA_TOKEN="$PRUSA_CONNECT_CAMERA_TOKEN"
        PRUSA_CONNECT_CAMERA_TOKEN=$(whiptail --inputbox "Enter Prusa Connect Camera Token:" \
            "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" "$PRUSA_CONNECT_CAMERA_TOKEN" 3>&1 1>&2 2>&3) ||
            PRUSA_CONNECT_CAMERA_TOKEN=$OLD_PRUSA_CONNECT_CAMERA_TOKEN
        ;;
    "3")
        # store old value in case of cancel
        OLD_CAMERA_COMMAND="$CAMERA_COMMAND"
        CAMERA_COMMAND=$(whiptail --inputbox "Enter Camera Command:" "$(min 10 "$MENU_HEIGHT")" \
            "$(min 60 "$MENU_WIDTH")" "$CAMERA_COMMAND" 3>&1 1>&2 2>&3) || CAMERA_COMMAND=$OLD_CAMERA_COMMAND
        ;;
    "4")
        # Escape dashes in the extra params
        EXTRA_PARAMS=${EXTRA_PARAMS/-/\\-}
        EXTRA_PARAMS=${EXTRA_PARAMS// -/ \\-}
        # store old value in case of cancel
        OLD_EXTRA_PARAMS="$EXTRA_PARAMS"
        EXTRA_PARAMS=$(whiptail --inputbox \
            "Enter Camera Command Extra Params (dashed commands need to be escaped with \\):" \
            "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" "$EXTRA_PARAMS" 3>&1 1>&2 2>&3) ||
            EXTRA_PARAMS=$OLD_EXTRA_PARAMS
        EXTRA_PARAMS=${EXTRA_PARAMS//\\/}
        ;;
    "5")
        # Final confirmation
        # Check if any field is empty
        if [[ -z "$PRINTER_ADDRESS" || -z "$PRUSA_CONNECT_CAMERA_TOKEN" ||
            -z "$CAMERA_COMMAND" || -z "$EXTRA_PARAMS" ]]; then
            whiptail --msgbox "All fields are required. Please fill in all details." \
                "$(min 10 "$MENU_HEIGHT")" "$(min 60 "$MENU_WIDTH")" 3>&1 1>&2 2>&3
            continue
        fi
        CONFIRMATION=(
            "Confirm your entries:\n"
            "Printer Address: $PRINTER_ADDRESS"
            "Camera Token: $PRUSA_CONNECT_CAMERA_TOKEN"
            "Camera Command: $CAMERA_COMMAND"
            "Extra Params: $EXTRA_PARAMS\n"
            "Continue?"
        )
        CONFIRMATION_TEXT
        IFS=$'\n' read -r -d '' CONFIRMATION_TEXT <<<"$(printf "%s\n" "${CONFIRMATION[@]}")"
        # Show confirmation dialog
        if whiptail --yesno "$CONFIRMATION_TEXT" "$(min 15 "$MENU_HEIGHT")" \
            "$(min 70 "$MENU_WIDTH")" 3>&1 1>&2 2>&3; then
            break # Exit loop and continue with the script
        fi
        ;;
    esac
done

# Save to .env file
{
    echo "PRINTER_ADDRESS=\"$PRINTER_ADDRESS\""
    echo "PRUSA_CONNECT_CAMERA_TOKEN=\"$PRUSA_CONNECT_CAMERA_TOKEN\""
    echo "PRUSA_CONNECT_CAMERA_FINGERPRINT=\"$(uuidgen)\""
    echo "CAMERA_COMMAND=\"$CAMERA_COMMAND\""
    echo "CAMERA_COMMAND_EXTRA_PARAMS=\"$EXTRA_PARAMS\""
    echo "CAMERA_DEVICE=/dev/video0"
} >"$ENV_FILE"

echo "Printer and camera details saved to $ENV_FILE"
