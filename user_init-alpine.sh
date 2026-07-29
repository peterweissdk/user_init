#!/bin/sh
# ----------------------------------------------------------------------------
# Script Name: user_init-alpine.sh
# Description: Ncurses user management for Alpine Linux
# Author: peterweissdk
# Email: peterweissdk@gmail.com
# Date: 2025-01-26
# Version: v0.1.2
# Usage: Run script with sudo, and follow menu instructions
# ----------------------------------------------------------------------------

VERSION="0.1.2"
SCRIPT_NAME="user_init"
SCRIPT_URL="https://raw.githubusercontent.com/peterweissdk/user_init/main/user_init-alpine.sh"
VERSION_URL="https://raw.githubusercontent.com/peterweissdk/user_init/main/user_init-alpine.sh"

# Function to display help
show_help() {
    echo "Usage: $SCRIPT_NAME [OPTIONS]"
    echo ""
    echo "Ncurses user management tool for Alpine Linux"
    echo ""
    echo "Options:"
    echo "  -v, --version    Show version information"
    echo "  -u, --update     Update script to latest version"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Run without options to start the interactive menu."
    echo "Note: This script requires root privileges."
}

# Function to display version
show_version() {
    echo "$SCRIPT_NAME version $VERSION"
}

# Function to compare versions (returns 0 if $1 > $2)
# POSIX-compatible version comparison
version_gt() {
    # Returns 0 (true) if $1 > $2
    test "$(printf '%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" != "$1"
}

# Function to update script
update_script() {
    echo "Checking for updates..."
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo "⛔ curl is required for updates. Install with: apk add curl"
        exit 1
    fi
    
    # Get remote version
    remote_script=$(curl -fsSL "$VERSION_URL" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "⛔ Failed to check for updates"
        exit 1
    fi
    
    remote_version=$(echo "$remote_script" | grep -m1 '^VERSION=' | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        echo "⛔ Failed to determine remote version"
        exit 1
    fi
    
    echo "Current version: $VERSION"
    echo "Latest version:  $remote_version"
    
    if version_gt "$remote_version" "$VERSION"; then
        echo "📥 Updating to version $remote_version..."
        
        # Get the path of the current script
        script_path=$(readlink -f "$0")
        
        # Create temp file
        tmp_file=$(mktemp)
        trap "rm -f $tmp_file" EXIT
        
        # Download new version
        if ! curl -fsSL "$SCRIPT_URL" -o "$tmp_file"; then
            echo "⛔ Failed to download update"
            exit 1
        fi
        
        # Install updated script
        if [ -w "$script_path" ]; then
            cp "$tmp_file" "$script_path" && chmod 755 "$script_path"
        elif sudo -n true 2>/dev/null; then
            sudo cp "$tmp_file" "$script_path" && sudo chmod 755 "$script_path"
        else
            echo "You need root privileges to update the script."
            sudo cp "$tmp_file" "$script_path" && sudo chmod 755 "$script_path"
        fi
        
        if [ $? -eq 0 ]; then
            echo "✅ Successfully updated to version $remote_version"
        else
            echo "⛔ Failed to install update"
            exit 1
        fi
    else
        echo "✅ Already running the latest version"
    fi
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version)
            show_version
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--update)
            update_script
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Check if dialog is installed
if ! command -v dialog >/dev/null 2>&1; then
    echo "Error: 'dialog' is not installed."
    printf "Do you want to install it now? (yes/no): "
    read answer
    case $answer in
        [Yy]* )
            apk add dialog
            if ! command -v dialog >/dev/null 2>&1; then
                echo "Failed to install dialog. Exiting."
                exit 1
            fi
            echo "dialog installed successfully."
            ;;
        * )
            echo "Exiting script."
            exit 0
            ;;
    esac
fi

# Function to setup a new user
setup_user() {
    USERNAME=$(dialog --inputbox "Enter username" 8 40 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if user already exists
    if id "$USERNAME" >/dev/null 2>&1; then
        dialog --title "Error" --msgbox "User $USERNAME already exists" 8 40
        return
    fi
    
    USERID=$(dialog --inputbox "Enter user ID (Leave blank for automatic)" 8 40 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # If user specified an ID, check if it's already in use
    if [ -n "$USERID" ]; then
        if getent passwd "$USERID" >/dev/null 2>&1; then
            dialog --title "Error" --msgbox "User ID $USERID is already in use" 8 40
            return
        fi
    fi
    
    PASSWORD=$(dialog --passwordbox "Enter password" 8 40 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    if [ -n "$USERID" ]; then
        adduser -D -u "$USERID" "$USERNAME"
    else
        adduser -D "$USERNAME"
    fi
    
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    if [ $? -eq 0 ]; then
        dialog --title "Success" --msgbox "User $USERNAME created successfully" 8 40
    else
        dialog --title "Error" --msgbox "Failed to create user $USERNAME" 8 40
    fi
}

# Function to setup sudo user (wheel group on Alpine)
setup_sudo_user() {
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=""
    for user in $USERS; do
        USER_ARRAY="$USER_ARRAY $user \"\""
    done
    
    if [ -z "$USER_ARRAY" ]; then
        dialog --title "Error" --msgbox "No eligible users found" 8 40
        return
    fi
    
    SELECTED_USER=$(eval "dialog --title \"Select User\" --menu \"Choose user to grant sudo access:\" 15 60 4 $USER_ARRAY" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if user is already in wheel group
    if groups "$SELECTED_USER" | grep -q "\bwheel\b"; then
        dialog --title "Warning" --msgbox "User $SELECTED_USER is already in wheel group" 8 40
        return
    fi
    
    # Check if sudo or doas is installed, offer to install if not
    if ! command -v sudo >/dev/null 2>&1 && ! command -v doas >/dev/null 2>&1; then
        dialog --title "No sudo/doas" --yesno "Neither sudo nor doas is installed.\nInstall sudo now?" 8 50
        if [ $? -eq 0 ]; then
            apk add sudo
            if ! command -v sudo >/dev/null 2>&1; then
                dialog --title "Error" --msgbox "Failed to install sudo" 8 40
                return
            fi
        else
            dialog --title "Cancelled" --msgbox "Cannot grant sudo access without sudo or doas installed" 8 50
            return
        fi
    fi
    
    # Configure sudo for wheel group if sudo is installed
    if command -v sudo >/dev/null 2>&1; then
        # Uncomment wheel group line in sudoers if commented
        if [ -f /etc/sudoers ]; then
            # Check if wheel is already enabled
            if ! grep -q "^%wheel" /etc/sudoers; then
                # Uncomment the wheel line or add it
                if grep -q "^# %wheel" /etc/sudoers; then
                    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
                else
                    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
                fi
            fi
        fi
    fi
    
    # Configure doas for wheel group if doas is installed
    if command -v doas >/dev/null 2>&1; then
        if [ ! -f /etc/doas.conf ] || ! grep -q "permit.*:wheel" /etc/doas.conf; then
            echo "permit persist :wheel" >> /etc/doas.conf
        fi
    fi
    
    adduser "$SELECTED_USER" wheel
    if [ $? -eq 0 ]; then
        dialog --title "Success" --msgbox "Added $SELECTED_USER to wheel group.\nSudo/doas access is now configured." 8 50
    else
        dialog --title "Error" --msgbox "Failed to add $SELECTED_USER to wheel group" 8 40
    fi
}

# Function to delete user
delete_user() {
    # Get the actual username of the user who ran sudo
    SUDO_USER_NAME=$(logname 2>/dev/null || echo "$SUDO_USER")
    
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=""
    for user in $USERS; do
        # Skip root user from the list
        if [ "$user" != "root" ]; then
            USER_ARRAY="$USER_ARRAY $user \"\""
        fi
    done
    
    if [ -z "$USER_ARRAY" ]; then
        dialog --title "Error" --msgbox "No eligible users to delete" 8 40
        return
    fi
    
    SELECTED_USER=$(eval "dialog --title \"Select User\" --menu \"Choose user to delete:\" 15 60 4 $USER_ARRAY" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if trying to delete the user who ran sudo
    if [ "$SELECTED_USER" = "$SUDO_USER_NAME" ]; then
        dialog --title "Error" --msgbox "You cannot delete your own user account ($SELECTED_USER)" 8 60
        return
    fi
    
    # Check if user is logged in
    if who | grep -wq "^$SELECTED_USER"; then
        dialog --title "Error" --msgbox "User $SELECTED_USER is currently logged in and cannot be deleted" 8 60
        return
    fi
    
    # Additional warning about user processes
    if pgrep -u "$SELECTED_USER" >/dev/null; then
        dialog --title "Warning" --yesno "User $SELECTED_USER has running processes. Still proceed with deletion?" 8 60
        if [ $? -ne 0 ]; then
            return
        fi
    fi
    
    dialog --title "Confirm" --yesno "Are you sure you want to delete user $SELECTED_USER and their home directory?" 8 60
    if [ $? -eq 0 ]; then
        deluser --remove-home "$SELECTED_USER"
        if [ $? -eq 0 ]; then
            dialog --title "Success" --msgbox "User $SELECTED_USER deleted successfully" 8 40
        else
            dialog --title "Error" --msgbox "Failed to delete user $SELECTED_USER" 8 40
        fi
    fi
}

# Function to setup Shell
setup_shell() {
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=""
    for user in $USERS; do
        USER_ARRAY="$USER_ARRAY $user \"\""
    done
    
    if [ -z "$USER_ARRAY" ]; then
        dialog --title "Error" --msgbox "No eligible users found" 8 40
        return
    fi
    
    SELECTED_USER=$(eval "dialog --title \"Select User\" --menu \"Choose user to setup Shell:\" 15 60 4 $USER_ARRAY" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    # Let user choose between ZSH and Fish
    SHELL_CHOICE=$(dialog --title "Shell Selection" --menu "Choose which shell to install:" 15 60 2 \
        "1" "Install ZSH Shell" \
        "2" "Install Fish Shell" \
        3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    case $SHELL_CHOICE in
        1)
            # Install zsh if not present
            if ! command -v zsh >/dev/null 2>&1; then
                # Attempt to install ZSH
                if ! (apk update && apk add zsh); then
                    dialog --title "Warning" --msgbox "There were errors during ZSH installation. Checking if it installed anyway..." 8 60
                fi
                # Check if ZSH is now available, regardless of installation exit status
                if ! command -v zsh >/dev/null 2>&1; then
                    dialog --title "Error" --msgbox "ZSH installation failed. The shell could not be found on the system." 8 60
                    return 1
                else
                    dialog --title "Success" --msgbox "ZSH has been successfully installed!" 8 60
                fi
            else
                dialog --title "Info" --msgbox "ZSH is already installed on the system." 8 60
            fi
            
            dialog --title "Default Shell" --yesno "Make ZSH the default shell for $SELECTED_USER?" 8 60
            if [ $? -eq 0 ]; then
                ZSH_PATH=$(which zsh)
                # Add zsh to /etc/shells if not present
                if ! grep -q "^$ZSH_PATH$" /etc/shells; then
                    echo "$ZSH_PATH" >> /etc/shells
                fi
                # Use sed to modify /etc/passwd directly (BusyBox chsh compatibility)
                if sed -i "s|^\($SELECTED_USER:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*|\1$ZSH_PATH|" /etc/passwd; then
                    dialog --title "Success" --msgbox "ZSH set as default shell for $SELECTED_USER" 8 60
                else
                    dialog --title "Error" --msgbox "Failed to set ZSH as default shell. Please try again." 8 60
                    return 1
                fi
            fi

            dialog --title "Oh My ZSH" --yesno "Install Oh My ZSH for $SELECTED_USER?" 8 60
            if [ $? -eq 0 ]; then
                # Check if curl is installed
                if ! command -v curl >/dev/null 2>&1; then
                    dialog --title "Error" --msgbox "Oh My ZSH installation failed! Curl is not installed. Please install curl first." 8 60
                    return 1
                fi

                # Install Oh My ZSH
                su - "$SELECTED_USER" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
                
                # Add TERM and ll alias after Oh My Zsh installation
                # Insert TERM export at the beginning of .zshrc for proper color support
                sed -i '1i export TERM="xterm-256color"' /home/$SELECTED_USER/.zshrc
                echo 'alias ll="ls -la"' >> /home/$SELECTED_USER/.zshrc
                chown $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.zshrc
                
                # Theme selection
                THEME=$(dialog --title "Select Theme" --menu "Choose a theme:" 20 60 12 \
                    "ys" "Ys Theme" \
                    "eastwood" "Eastwood Theme" \
                    "simple" "Simple Theme" \
                    "lukerandall" "Lukerandall Theme" \
                    "gozilla" "Gozilla Theme" \
                    "kphoen" "Kphoen Theme" \
                    "jonathan" "Jonathan Theme" \
                    "minimal" "Minimal Theme" \
                    "apple" "Apple Theme" \
                    "gnzh" "Gnzh Theme" \
                    "nanotech" "Nanotech Theme" \
                    "agnoster" "Agnoster Theme" \
                    "miloshadzic" "Miloshadzic Theme" 3>&1 1>&2 2>&3)
                    
                if [ $? -eq 0 ]; then
                    sed -i "s/ZSH_THEME=.*/ZSH_THEME=\"$THEME\"/" /home/$SELECTED_USER/.zshrc
                    dialog --title "Theme Installed" --msgbox "Theme '$THEME' has been set as your ZSH theme.\nIt will be active next time you log in." 10 50
                fi
                
                # Set proper ownership
                chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.zshrc
                chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.oh-my-zsh 2>/dev/null
            fi
            ;;
            
        2)
            # Install fish if not present
            if ! command -v fish >/dev/null 2>&1; then
                # Attempt to install Fish
                if ! (apk update && apk add fish); then
                    dialog --title "Warning" --msgbox "There were errors during Fish installation. Checking if it installed anyway..." 8 60
                fi
                # Check if Fish is now available, regardless of installation exit status
                if ! command -v fish >/dev/null 2>&1; then
                    dialog --title "Error" --msgbox "Fish installation failed. The shell could not be found on the system." 8 60
                    return 1
                else
                    dialog --title "Success" --msgbox "Fish shell has been successfully installed!" 8 60
                fi
            else
                dialog --title "Info" --msgbox "Fish shell is already installed on the system." 8 60
            fi
            
            dialog --title "Default Shell" --yesno "Make Fish the default shell for $SELECTED_USER?" 8 60
            if [ $? -eq 0 ]; then
                FISH_PATH=$(which fish)
                # Add fish to /etc/shells if not present
                if ! grep -q "^$FISH_PATH$" /etc/shells; then
                    echo "$FISH_PATH" >> /etc/shells
                fi
                # Use sed to modify /etc/passwd directly (BusyBox chsh compatibility)
                if sed -i "s|^\($SELECTED_USER:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*|\1$FISH_PATH|" /etc/passwd; then
                    dialog --title "Success" --msgbox "Fish set as default shell for $SELECTED_USER" 8 60
                else
                    dialog --title "Error" --msgbox "Failed to set Fish as default shell. Please try again." 8 60
                    return 1
                fi
            fi
            
            # Add ll alias to fish config
            mkdir -p /home/$SELECTED_USER/.config/fish
            echo 'alias ll="ls -la"' >> /home/$SELECTED_USER/.config/fish/config.fish
            
            # Set proper ownership
            chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.config/fish
            ;;
    esac
}

# Function to setup SSH key
setup_ssh_key() {
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=""
    for user in $USERS; do
        USER_ARRAY="$USER_ARRAY $user \"\""
    done
    
    if [ -z "$USER_ARRAY" ]; then
        dialog --title "Error" --msgbox "No eligible users found" 8 40
        return
    fi
    
    SELECTED_USER=$(eval "dialog --title \"Select User\" --menu \"Choose user to setup SSH key:\" 15 60 4 $USER_ARRAY" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    SSH_KEY=$(dialog --inputbox "Paste the public SSH key" 12 80 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Create .ssh directory with proper permissions
    mkdir -p /home/$SELECTED_USER/.ssh
    chmod 700 /home/$SELECTED_USER/.ssh
    
    # Append SSH key to authorized_keys
    echo "$SSH_KEY" >> /home/$SELECTED_USER/.ssh/authorized_keys
    chmod 600 /home/$SELECTED_USER/.ssh/authorized_keys
    
    # Set proper ownership
    chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.ssh
    
    dialog --title "Success" --msgbox "SSH key has been appended for $SELECTED_USER" 8 40
}

# Main menu loop
while true; do
    CHOICE=$(dialog --title "User initialization v${VERSION}" --cancel-label "Exit" --menu "Choose an option:" 18 60 5 \
        "1" "Setup User" \
        "2" "Setup Sudo User" \
        "3" "Delete User" \
        "4" "Setup User Shell" \
        "5" "Setup SSH Key" \
        3>&1 1>&2 2>&3)
    
    EXIT_STATUS=$?
    
    if [ $EXIT_STATUS != 0 ]; then
        clear
        exit 0
    fi
    
    case $CHOICE in
        1)
            setup_user
            ;;
        2)
            setup_sudo_user
            ;;
        3)
            delete_user
            ;;
        4)
            setup_shell
            ;;
        5)
            setup_ssh_key
            ;;
    esac
done
