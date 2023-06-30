#!/bin/bash

term_colors() {
    # Set colors for use in print_message TASK terminal output functions
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        CYAN=$(printf '\033[36m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        ORANGE=$(printf '\033[38;5;208m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[0m')
        CLEAR_LINE=$(tput el)
    else
        RED=""
        GREEN=""
        CYAN=""
        YELLOW=""
        BLUE=""
        ORANGE=""
        BOLD=""
        RESET=""
        CLEAR_LINE=""
    fi
}

# Initialise global terminal colors
term_colors

# Print formated terminal messages
print_message() {
    local option=${1}
    local text=${2}
    local terminal_width=$(tput cols)
    local max_chars=$((terminal_width - 8))
    local truncated_text=$(truncate_text "$text" $max_chars)

    local border_sym=$' '
    local info_sym=$'i'
    local task_sym=$'i'
    local pass_sym=$'\u2714'      
    local fail_sym=$'\u2718'      
    local warn_sym=$'\u26A0'      
    local skip_sym=$'s'      
    local user_sym=$'u' 
    local done_sym=$'\u2714'     
    local blank_sym=$' '         


    # Preserve newline or carriage return at the end, if present
    local preserved_chars=""
    if [[ "$text" =~ [[:space:]]$ ]]; then
        preserved_chars=${text: -1}
    fi

    case "${option}" in
        INFOFULL)
            format="${border_sym}${BOLD}${CYAN}${info_sym} %s${RESET}\n"
            ;;
        INFO)
            format="${border_sym}${BOLD}${CYAN}${info_sym}${RESET} %s\n"
            ;;
        TASK)
            format="${border_sym}${BOLD}${task_sym}${RESET} %s"
            ;;
        WARN)
            format="${border_sym}${YELLOW}${warn_sym} %s${RESET}\n"
            ;;
        USER)
            format="${border_sym}${BOLD}${GREEN}${user_sym}${RESET} %s\n"
            ;;
        SKIP)
            format="${border_sym}${BOLD}${BLUE}${skip_sym}${RESET} %s\n"
            ;;
        FAIL)
            format="${border_sym}${RED}${fail_sym} %s${RESET}\n"
            ;;
        BLANK)
            format="${border_sym}${blank_sym} %s\n"
            ;;
        DONE)
            format="${border_sym}${BOLD}${GREEN}${done_sym} %s${RESET}\n"
            ;;
        PASS)
            format="${border_sym}${GREEN}${pass_sym} %s${RESET}\n"
            ;;
        *)
            format="%s"
            ;;
    esac

    printf "\r${format}${CLEAR_LINE}" "${truncated_text}${preserved_chars}"
}


check_gnome() {
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        print_message PASS "Running GNOME environment."
        GNOME_SHELL_VERSION=$(gnome-shell --version | grep -oP '[0-9]+\.[0-9]+')
        print_message INFO "GNOME desktop version: ${GNOME_SHELL_VERSION}"
    else
        print_message FAIL "GNOME desktop environment not detected. Exiting..."
        exit 1
    fi
}


# Function to truncate text if it exceeds the maximum length
truncate_text() {
    local text="$1"
    local max_chars="$2"
    local ellipsis="..."

    if [ ${#text} -gt $max_chars ]; then
        echo -n "${text:0:$max_chars}${ellipsis}"
    else
        echo -n "$text"
    fi
}

# Debian apt package related functions
# Example usage: pkgmgr install curl wget htop nmap
function pkgmgr() {
	for pkg in "${@:2}"; do
        local snapinstalled=false
        local aptinstalled=false

        print_message TASK "Checking for package: ${pkg}..."
        if command -v snap >/dev/null 2>&1; then
            if sudo snap list | grep -q "^${pkg} "; then
                print_message INFO "Found snap installation of package: ${pkg}"
                snapinstalled=true
            fi
        fi

        if dpkg -s "${pkg}" >/dev/null 2>&1; then
            print_message INFO "Found apt installation of package: ${pkg}"
            aptinstalled=true
        fi

        if [[ ${snapinstalled} == false && ${aptinstalled} == false ]]; then
            print_message INFO "No installed snap or apt package for: ${pkg}"
        fi

        case ${1} in
            install)
                if [[ ${snapinstalled} == false && ${aptinstalled} == false ]]; then
                    print_message INFO "Attempting to install ${pkg}..."
                    if [[ "${pkg}" == *.deb ]]; then
                        run_command_verbose sudo dpkg -i "${pkg}"
                    else
                        run_command_verbose sudo apt -y install "${pkg}"
                    fi

                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully installed package: ${pkg}."
                    else
                        print_message FAIL "Failed to install package: ${pkg}."
                    fi

                fi
            ;;
            remove)
                if [[ ${snapinstalled} == true ]]; then
                    run_command sudo snap remove "${pkg}"
                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message PASS "Successfully removed snap package: ${pkg}."
                    else
                        print_message FAIL "Failed to remove snap package: ${pkg}."
                    fi
                elif [[ ${aptinstalled} == true ]]; then
                    run_command sudo apt -y remove "${pkg}"
                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message FAIL "Failed to remove package: ${pkg}."
                    else
                        print_message PASS "Successfully removed package: ${pkg}."
                    fi
                fi
            ;;
            purge)
                if [[ ${aptinstalled} == true ]]; then
                    run_command sudo apt -y purge "${pkg}"
                    command_result_code=$?
                    if [[ "${command_result_code}" -eq 0 ]]; then
                        print_message FAIL "Failed to purge package: ${pkg}."
                    else
                        print_message PASS "Successfully removed package: ${pkg}."
                    fi
                fi
            ;;
            find)
                if [[ $(sudo apt-cache search --names-only "^${pkg}$" | wc -l) == "1" ]]; then
                    pkg_match=$(sudo dpkg --get-selections | grep "^${pkg}" | awk '{print $1}')
                    echo -ne ${pkg_match}
                fi
            ;;
            size)
                if [[ $(sudo apt-cache --no-all-versions show ${pkg} | grep '^Size: ' | wc -l) == "1" ]]; then
                    pkg_raw_size=$(sudo apt-cache --no-all-versions show ${pkg} | grep '^Size: ' | awk '{print $2}')
                    pkg_size="$(echo ${pkg_raw_size} | numfmt --to=iec)"
                    print_message INFO "The installation size of package ${pkg} is ${pkg_size}."
                fi
            ;;
            *) 
                print_message FAIL "Invalid pkgmgr() function usage."
            ;;
        esac
	done
}

# Function performs all package updates, upgrades, fixes and cleaning.
function pkgchk() {
    print_message INFOFULL "Updating, upgrading, fixing system packages..."
    run_command sudo apt -y update
    run_command_verbose sudo apt -y upgrade
    run_command sudo apt -y --fix-broken install
    run_command sudo apt -y autoclean
    run_command sudo apt -y autoremove
}

# Function runs commands and suppresses output.
# Best for commands with short execution time.
# A true or 0 result can be forced to prevent a fail message.
function run_command() {
    local command_output
    local force_zero=false
    local command=()
    local command_string=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -z|--force-zero)
                force_zero=true
                shift
                ;;
            *)
                command+=("$1")
                if [ -z "$command_string" ]; then
                    command_string="$1"
                else
                    command_string+=" $1"
                fi
                shift
                ;;
        esac
    done

    command_string=$(trim "$command_string")

    print_message TASK "${command_string}"
    if [ "$force_zero" = true ]; then
        command_output=$( "${command[@]}" >/dev/null 2>&1 )
        print_message PASS
    else
        command_output=$( "${command[@]}" 2>&1 )
        local exit_status=$?
        if [ $exit_status -eq 0 ]; then
            print_message PASS "${command_string}"
        else
            if [ -n "$command_output" ]; then
                print_message FAIL "${command_string}"
                print_message BLANK "${RED}${command_output}${RESET}"
            else
                print_message FAIL "${command_string}"
            fi
        fi
    fi
}

# Function runs commands with full output.
# Best for commands with long execution time or signicant output.
function run_command_verbose() {
    local command=("$@")
    local command_string="${command[*]}"

    print_message TASK "${command_string}"
    "${command[@]}"
}

# Function to trim leading and trailing whitespace
function trim() {
    var="$*"
    var="$(echo "$var" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo -n "$var"
}


# Display press any key or do you wish to continue y/N.
# Example usage: wait_for user_anykey OR wait_for user_continue
function wait_for() {
    echo
    if [ -z "${2}" ]; then
        message="Do you wish to continue"
    else
        message="${2}"
    fi

    case "${1}" in
        user_anykey) read -n 1 -s -r -p "[${GREEN}USER${RESET}] Press any key to continue. "
        echo -e "\n"
        ;;
        user_continue) local response
        while true; do
            read -r -p "[${GREEN}USER${RESET}] ${message} (y/N)?${RESET} " response
            case "${response}" in
            [yY][eE][sS] | [yY])
                echo
                break
                ;;
            *)
                echo
                exit
                ;;
            esac
        done;;
        *) message FAIL "Invalid function usage.";;
    esac
}


# Big function used to GNOME extension management.
# Supports install, uninstall, enable and disable as actions.
# Using `extmgr disable ALL` will disable all extensions.
function extmgr() {
    action="${1}"
    extension_list="${2}"
    extensions=()

    if [ "${extension_list}" = "ALL" ]; then
        extensions=($(gnome-extensions list --quiet))
    else
        while IFS= read -r line; do
            # Remove leading/trailing whitespace from extension ID
            extension_item="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

            # Skip empty lines
            if [ -n "${extension_item}" ]; then
                extensions+=("${extension_item}")
            fi
        done <<< "${extension_list}"
    fi

    if [ "${#extensions[@]}" -eq 0 ]; then
        print_message TASK "No extensions set.\n"
        exit 1
    fi

    if [ "${action}" = "uninstall" ]; then
        print_message INFOFULL "Uninstalling GNOME extensions..."
        for extension_item in "${extensions[@]}"; do
            if gnome-extensions list | grep -q "${extension_item}"; then
                # Extension is installed, disable and uninstall
                run_command gnome-extensions disable "${extension_item}"
                run_command gnome-extensions uninstall "${extension_item}"

                extension_path="${HOME}/.local/share/gnome-shell/extensions/${extension_item}"
                if [[ -d ${extension_path} ]]; then
                    run_command rm -rf "${extension_path}"
                fi
            else
                print_message SKIP "Extension ${extension_item} is not installed"
            fi
        done
    fi

    if [ "${action}" = "install" ]; then
        print_message INFOFULL "Installing GNOME extensions..."
        for extension_item in "${extensions[@]}"; do
            if gnome-extensions list | grep -q "${extension_item}"; then
                print_message SKIP "Extension ${extension_item} is already installed"
                continue
            else
                if [[ $extension_item =~ ^[0-9]{1,4}$ ]]; then
                    print_message INFO "Searching for extension by pk ID..."
                    extension_url="https://extensions.gnome.org/extension-info/?pk=${extension_item}&shell_version=${GNOME_SHELL_VERSION}"
                else
                    print_message INFO "Searching for extension by UUID ID..."
                    extension_url="https://extensions.gnome.org/extension-info/?uuid=${extension_item}&shell_version=${GNOME_SHELL_VERSION}"
                fi

                url_response=$(curl -s -o /dev/null -w "%{http_code}" "$extension_url")

                if [ "$url_response" = 404 ]; then
                    print_message WARN "No GNOME extension found for ${extension_item} and GNOME shell version ${GNOME_SHELL_VERSION}"
                    continue
                fi

                url_content="$(curl -s "$extension_url")"

                values=(
                    "pk"
                    "name"
                    "download_url"
                    "uuid"
                    "version"
                    "link"
                ) 

                for value_name in "${values[@]}"; do
                    variable_name="extension_${value_name}"
                    value="$(echo "${url_content}" | jq -r ".${value_name}")"
                    declare "${variable_name}=${value}"
                done

                if [ -z "$extension_uuid" ]; then
                    print_message FAIL "No UUID returned for ${extension_item}. Unable to install extension."
                else
                    print_message PASS "Found ${extension_item} for GNOME ${GNOME_SHELL_VERSION} at extensions.gnome.org..."
                    for value_name in "${values[@]}"; do
                        variable_name="extension_${value_name}"
                        print_message INFO "${variable_name}: ${!variable_name}"
                    done
                    run_command_verbose busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s "${extension_uuid}"
                fi
            fi
        done
    fi

    if [ "${action}" = "enable" ]; then
        print_message INFOFULL "Enabling GNOME extensions..."
        run_command gsettings set org.gnome.shell disable-user-extensions false
        for extension_item in "${extensions[@]}"; do
            is_enabled=$(gnome-extensions list --enabled | grep "${extension_item}")
            if [ -z "${is_enabled}" ]; then
                run_command gnome-extensions enable "${extension_item}"
            else
                print_message SKIP "Extension ${extension_item} is already enabled"
            fi
        done
    fi

    if [ "${action}" = "disable" ]; then
        print_message INFOFULL "Disabling GNOME extensions..."
        for extension_item in "${extensions[@]}"; do
            is_enabled=$(gnome-extensions list --enabled | grep "${extension_item}")
            if [ -z "${is_enabled}" ]; then
                print_message SKIP "Extension ${extension_item} is already disabled"
            else
                run_command gnome-extensions disable "${extension_item}"
            fi
        done
        if [ "${extension_list}" = "ALL" ]; then
            run_command gsettings set org.gnome.shell disable-user-extensions true
        fi
    fi
}

# Function used to customise GNOME theme.
function custom_theme() {
    print_message INFOFULL "Customising GNOME theme..."
    # Setup and install new theme and icons
    run_command mkdir -p ~/.themes
    run_command mkdir -p ~/.icons
    pkgmgr install arc-theme papirus-icon-theme curl

    # Set current theme values
    run_command gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark'
    run_command gsettings set org.gnome.desktop.wm.preferences theme 'Arc-Dark'
    run_command gsettings set org.gnome.shell.extensions.user-theme name 'Arc-Dark'
    run_command gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
}

# Function used to customise default GNOME terminal colors.
function custom_terminal() {
    print_message INFOFULL "Customising Terminal colors..."

    # Get the list of profiles
    profiles=$(dconf list /org/gnome/terminal/legacy/profiles:/)

    # Optional - Set DEFAULT_PROFILE manually by getting profile ID using `dconf list /org/gnome/terminal/legacy/profiles:/`
    # Method below will attempt to extract the default profile, assuming default is first

    default_profile=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')

    profile="/org/gnome/terminal/legacy/profiles:/:${default_profile}"

    # Scheme similar to Kali dark color
    palette="['#0d1117', '#ff6685', '#aaffaa', '#ffe156', '#00a2ff', '#c594c5', '#00ffff', '#cccccc', '#666666', '#ff669d', '#aaffaa', '#ffe156', '#00a2ff', '#c594c5', '#00ffff', '#ffffff']"
    foreground_color="'#eeeeee'"
    background_color="'#0d1117'"
    bold_color="'#babdb6'"

    # Set the color scheme
    run_command dconf write "${profile}/palette" "${palette}"
    run_command dconf write "${profile}/foreground-color" "${foreground_color}"
    run_command dconf write "${profile}/background-color" "${background_color}"
    run_command dconf write "${profile}/bold-color" "${bold_color}"
    run_command dconf write "${profile}/bold-color-same-as-fg" "false"
    run_command dconf write "${profile}/use-theme-colors" "false"
}

function install_prereqs() {
    print_message INFOFULL "Installing required system packages..."
    # Required packages to manage extensions
    pkgmgr install gnome-tweaks
    pkgmgr install gnome-shell-extensions
    pkgmgr install gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 gnome-system-monitor
}


banner() {
echo ${GREEN}
cat << "EOF"
     ____  __________  _______   ______  __  _________
    / __ \/ ____/ __ )/ ____/ | / / __ \/  |/  / ____/
   / / / / __/ / __  / / __/  |/ / / / / /|_/ / __/   
  / /_/ / /___/ /_/ / /_/ / /|  / /_/ / /  / / /___   
 /_____/_____/_____/\____/_/ |_/\____/_/  /_/_____/    

EOF
echo " ${RESET}A bash script for GNOME desktop customisation."
echo " Compatible with most Debian based distros."
echo
}

main() {
    clear
    banner
    check_gnome

    # Extensions to be installed
    EXTENSIONS="
    dash-to-dock@micxgx.gmail.com
    arcmenu@arcmenu.com
    user-theme@gnome-shell-extensions.gcampax.github.com
    auto-move-windows@gnome-shell-extensions.gcampax.github.com
    launch-new-instance@gnome-shell-extensions.gcampax.github.com
    native-window-placement@gnome-shell-extensions.gcampax.github.com
    screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com
    workspace-indicator@gnome-shell-extensions.gcampax.github.com
    tophat@fflewddur.github.io
    "

    print_message INFO "The following list of extensions will be installed:"
    printf "%s" "$EXTENSIONS"

    wait_for user_continue

    # Update and upgrade current packages. Clean up and any fix broken installs.
    pkgchk

    # Install requirements
    install_prereqs

    # Install and enable extensions
    extmgr install "${EXTENSIONS}"
    extmgr enable "${EXTENSIONS}"

    wait_for user_continue "Do you want to install the custom GNOME theme ARC"
    # Customise GNOME theme
    custom_theme

    wait_for user_continue "Do you want to install customise the GNOME terminal colors"
    # Customise GNOME terminal
    custom_terminal

    print_message DONE "Script completed."
}

main