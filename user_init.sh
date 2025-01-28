#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: user_init.sh
# Description: Ncurses user management
# Author: peterweissdk
# Email: peterweissdk@gmail.com
# Date: 2025-01-26
# Version: v0.1.0
# Usage: Run script with sudo, and follow menu instructions
# ----------------------------------------------------------------------------

# Installs script
install() {
    read -p "Do you want to install this script? (yes/no): " answer
    case $answer in
        [Yy]* )
            # Set default installation path
            default_path="/usr/local/bin"
            
            # Prompt for installation path
            read -p "Enter the installation path [$default_path]: " install_path
            install_path=${install_path:-$default_path}  # Use default if no input

            # Get the filename of the script
            script_name=$(basename "$0")

            # Copy the script to the specified path
            echo "Copying $script_name to $install_path..."
            
            # Check if the user has write permissions
            if [ ! -w "$install_path" ]; then
                echo "You need root privileges to install the script in $install_path."
                if sudo cp "$0" "$install_path/$script_name"; then
                    sudo chmod +x "$install_path/$script_name"
                    echo "Script installed successfully."
                else
                    echo "Failed to install script."
                    exit 1
                fi
            else
                if cp "$0" "$install_path/$script_name"; then
                    chmod +x "$install_path/$script_name"
                    echo "Script installed successfully."
                else
                    echo "Failed to install script."
                    exit 1
                fi
            fi
            ;;
        [Nn]* )
            echo "Exiting script."
            exit 0
            ;;
        * )
            echo "Please answer yes or no."
            install
            ;;
    esac

    exit 0
}

# Updates version of script
update_version() {
    # Extract the current version from the script header
    version_line=$(grep "^# Version:" "$0")
    current_version=${version_line#*: }  # Remove everything up to and including ": "
    
    echo "Current version: $current_version"
    
    # Prompt the user for a new version
    read -p "Enter new version (current: $current_version): " new_version
    
    # Update the version in the script
    sed -i "s/^# Version: .*/# Version: $new_version/" "$0"
    
    echo "Version updated to: $new_version"

    exit 0
}

# Prints out version
version() {
    # Extract the current version from the script header
    version_line=$(grep "^# Version:" "$0")
    current_version=${version_line#*: }  # Remove everything up to and including ": "
    
    echo "$0: $current_version"

    exit 0
}

# Prints out help
help() {
    echo "Run script to setup a new shell script file."
    echo "Usage: $0 [-i | --install] [-u | --update-version] [-v | --version] [-h | --help]"

    exit 0
}

# Check for flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--install) install; shift ;;
        -u|--update-version) update_version; shift ;;
        -v|--version) version; shift ;;
        -h|--help) help; shift ;;
        *) echo "Unknown option: $1"; help; exit 1 ;;
    esac
done

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Function to setup a new user
setup_user() {
    USERNAME=$(whiptail --inputbox "Enter username" 8 40 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if user already exists
    if id "$USERNAME" &>/dev/null; then
        whiptail --title "Error" --msgbox "User $USERNAME already exists" 8 40
        return
    fi
    
    USERID=$(whiptail --inputbox "Enter user ID (Leave blank for automatic)" 8 40 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # If user specified an ID, check if it's already in use
    if [ -n "$USERID" ]; then
        if id -u "$USERID" &>/dev/null; then
            whiptail --title "Error" --msgbox "User ID $USERID is already in use" 8 40
            return
        fi
    fi
    
    PASSWORD=$(whiptail --passwordbox "Enter password" 8 40 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    if [ -n "$USERID" ]; then
        useradd -m -u "$USERID" "$USERNAME"
    else
        useradd -m "$USERNAME"
    fi
    
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    if [ $? -eq 0 ]; then
        whiptail --title "Success" --msgbox "User $USERNAME created successfully" 8 40
    else
        whiptail --title "Error" --msgbox "Failed to create user $USERNAME" 8 40
    fi
}

# Function to setup sudo user
setup_sudo_user() {
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=()
    for user in $USERS; do
        USER_ARRAY+=("$user" "")
    done
    
    SELECTED_USER=$(whiptail --title "Select User" --menu "Choose user to grant sudo access:" 15 60 4 "${USER_ARRAY[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if user is already in sudo group
    if groups "$SELECTED_USER" | grep -q "\bsudo\b"; then
        whiptail --title "Warning" --msgbox "User $SELECTED_USER is already in sudo group" 8 40
        return
    fi
    
    usermod -aG sudo "$SELECTED_USER"
    if [ $? -eq 0 ]; then
        whiptail --title "Success" --msgbox "Added $SELECTED_USER to sudo group" 8 40
    else
        whiptail --title "Error" --msgbox "Failed to add $SELECTED_USER to sudo group" 8 40
    fi
}

# Function to delete user
delete_user() {
    # Get the actual username of the user who ran sudo
    SUDO_USER_NAME=$(logname 2>/dev/null || echo "$SUDO_USER")
    
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=()
    for user in $USERS; do
        # Skip root user from the list
        if [ "$user" != "root" ]; then
            USER_ARRAY+=("$user" "")
        fi
    done
    
    if [ ${#USER_ARRAY[@]} -eq 0 ]; then
        whiptail --title "Error" --msgbox "No eligible users to delete" 8 40
        return
    fi
    
    SELECTED_USER=$(whiptail --title "Select User" --menu "Choose user to delete:" 15 60 4 "${USER_ARRAY[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if trying to delete the user who ran sudo
    if [ "$SELECTED_USER" = "$SUDO_USER_NAME" ]; then
        whiptail --title "Error" --msgbox "You cannot delete your own user account ($SELECTED_USER)" 8 60
        return
    fi
    
    # Check if user is logged in
    if who | grep -wq "^$SELECTED_USER"; then
        whiptail --title "Error" --msgbox "User $SELECTED_USER is currently logged in and cannot be deleted" 8 60
        return
    fi
    
    # Additional warning about user processes
    if pgrep -u "$SELECTED_USER" >/dev/null; then
        if ! (whiptail --title "Warning" --yesno "User $SELECTED_USER has running processes. Still proceed with deletion?" 8 60); then
            return
        fi
    fi
    
    if (whiptail --title "Confirm" --yesno "Are you sure you want to delete user $SELECTED_USER and their home directory?" 8 60); then
        deluser --remove-home "$SELECTED_USER"
        if [ $? -eq 0 ]; then
            whiptail --title "Success" --msgbox "User $SELECTED_USER deleted successfully" 8 40
        else
            whiptail --title "Error" --msgbox "Failed to delete user $SELECTED_USER" 8 40
        fi
    fi
}

# Function to setup ZSH
setup_zsh() {
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=()
    for user in $USERS; do
        USER_ARRAY+=("$user" "")
    done
    
    SELECTED_USER=$(whiptail --title "Select User" --menu "Choose user to setup ZSH:" 15 60 4 "${USER_ARRAY[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Install zsh if not present
    if ! command -v zsh &> /dev/null; then
        apt-get update && apt-get install -y zsh
    fi
    
    if (whiptail --title "Default Shell" --yesno "Make ZSH the default shell for $SELECTED_USER?" 8 60); then
        chsh -s $(which zsh) "$SELECTED_USER"
    fi
    
    if (whiptail --title "Oh My ZSH" --yesno "Install Oh My ZSH for $SELECTED_USER?" 8 60); then
        # Install Oh My ZSH
        su - "$SELECTED_USER" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
        
        # Add ll alias
        echo 'alias ll="ls -la"' >> /home/$SELECTED_USER/.zshrc
        
        # Theme selection
        THEME=$(whiptail --title "Select Theme" --menu "Choose a theme:" 20 60 12 \
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
            whiptail --title "Theme Installed" --msgbox "Theme '$THEME' has been set as your ZSH theme.\nIt will be active next time you log in." 10 50
        fi
    fi
    
    # Set proper ownership
    chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.zshrc
    chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.oh-my-zsh 2>/dev/null
}

# Function to setup SSH key
setup_ssh_key() {
    USERS=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd)
    USER_ARRAY=()
    for user in $USERS; do
        USER_ARRAY+=("$user" "")
    done
    
    SELECTED_USER=$(whiptail --title "Select User" --menu "Choose user to setup SSH key:" 15 60 4 "${USER_ARRAY[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    SSH_KEY=$(whiptail --inputbox "Paste the public SSH key" 12 80 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi
    
    # Create .ssh directory with proper permissions
    mkdir -p /home/$SELECTED_USER/.ssh
    chmod 700 /home/$SELECTED_USER/.ssh
    
    # Append SSH key to authorized_keys
    echo "$SSH_KEY" >> /home/$SELECTED_USER/.ssh/authorized_keys
    chmod 600 /home/$SELECTED_USER/.ssh/authorized_keys
    
    # Set proper ownership
    chown -R $SELECTED_USER:$SELECTED_USER /home/$SELECTED_USER/.ssh
    
    whiptail --title "Success" --msgbox "SSH key has been appended for $SELECTED_USER" 8 40
}

# Main menu loop
while true; do
    CHOICE=$(whiptail --title "User Management" --cancel-button "Exit" --menu "Choose an option:" 18 60 5 \
        "1" "Setup User" \
        "2" "Setup Sudo User" \
        "3" "Delete User" \
        "4" "Setup ZSH Shell" \
        "5" "Setup SSH Key" \
        3>&1 1>&2 2>&3)
    
    EXIT_STATUS=$?
    
    if [ $EXIT_STATUS != 0 ]; then
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
            setup_zsh
            ;;
        5)
            setup_ssh_key
            ;;
    esac
done