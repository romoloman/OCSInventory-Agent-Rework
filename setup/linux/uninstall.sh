#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	log "ERROR" "The uninstallation script requires elevated privileges, please run as root" false
	exit 1
fi

# Constants
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
SERVICE_NAME="ocsinventory-agent"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent"
STORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent"

# Function to display usage information
usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  -S, --silent          Enable silent mode"
	echo "  -D, --hard-delete     Remove configs, log files and store data directory"
	echo "  -y, --yes             Automatically confirm uninstallation without prompting"
	echo "  -h, --help            Display this help message"
	exit 1
}

# Log formatting function
log() {
	local type="$1"
	local message="$2"
	local only_file="$3"

	if [ "$SILENT" = false ]; then
		if [ "$only_file" = false ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" | tee -a "${WORKING_DIRECTORY}/uninstall.log"
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" >>"${WORKING_DIRECTORY}/uninstall.log"
		fi
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" >>"${WORKING_DIRECTORY}/uninstall.log"
	fi
}

# Function to execute a command
execCommand() {
	local command="$1"
	local successMessage="$2"
	local errorMessage="$3"

	if $command >/dev/null 2>/dev/null; then
		log "INFO" "$successMessage" false
	else
		log "WARNING" "$errorMessage" false
	fi
}

# Default values
SILENT=false
HARD_DELETE=false
AUTO_CONFIRM=false

# options
SHORT_OPTS="hSDy"
LONG_OPTS="help,silent,hard-delete,yes"

# parse options
if ! PARSED_OPTIONS=$(getopt --options $SHORT_OPTS --longoptions $LONG_OPTS --name "$0" -- "$@"); then
	usage
fi

eval set -- "$PARSED_OPTIONS"
unset PARSED_OPTIONS

# process options
while true; do
	case "$1" in
	-S | --silent)
		SILENT=true
		shift
		;;
	-D | --hard-delete)
		HARD_DELETE=true
		shift
		;;
	-y | --yes)
		AUTO_CONFIRM=true
		shift
		;;
	-h | --help)
		usage
		;;
	--)
		shift
		break
		;;
	*)
		log "ERROR" "Internal error!" false
		exit 1
		;;
	esac
done

# Function to uninstall the agent
uninstall_agent() {
	if [ "$SILENT" = true ]; then
		log "INFO" "+-----------------------------------------------------------+" false
		log "INFO" "|                                                           |" false
		log "INFO" "|     Uninstalling OCSInventory Agent in silent mode...     |" false
		log "INFO" "|                                                           |" false
		log "INFO" "+-----------------------------------------------------------+" false
		log "INFO" "" false
	else
		log "INFO" "+----------------------------------------------------------------+" false
		log "INFO" "|                                                                |" false
		log "INFO" "|     Uninstalling OCSInventory Agent in interactive mode...     |" false
		log "INFO" "|                                                                |" false
		log "INFO" "+----------------------------------------------------------------+" false
		log "INFO" "" false
	fi

	if systemctl -q list-units --full -all | grep -q ${SERVICE_NAME}.service; then
		log "INFO" "Service ${SERVICE_NAME} exists, proceeding with uninstallation." false

		execCommand "systemctl -q stop ${SERVICE_NAME}" "Service ${SERVICE_NAME} stopped successfully." "Failed to stop service ${SERVICE_NAME}. It may not be running."

		execCommand "systemctl -q disable ${SERVICE_NAME}" "Service ${SERVICE_NAME} disabled successfully." "Failed to disable service ${SERVICE_NAME}."

		execCommand "rm ${SERVICE_FILE}" "Service file ${SERVICE_FILE} removed successfully." "Failed to remove service file ${SERVICE_FILE}."

		execCommand "systemctl -q daemon-reload" "Systemd daemon reloaded successfully." "Failed to reload systemd daemon."
	else
		log "WARNING" "Service ${SERVICE_NAME} does not exist." false
	fi

	if [ "$HARD_DELETE" = true ]; then
		execCommand "rm -r ${CONFIG_PATH}" "Configuration directory ${CONFIG_PATH} removed successfully." "Failed to remove configuration directory ${CONFIG_PATH}."

		execCommand "rm -r ${LOG_PATH}" "Log directory ${LOG_PATH} removed successfully." "Failed to remove log directory ${LOG_PATH}."

		execCommand "rm -r ${STORE_DATA_PATH}" "Store data directory ${STORE_DATA_PATH} removed successfully." "Failed to remove store data directory ${STORE_DATA_PATH}."
	fi

	execCommand "rm -r ${AGENT_INSTALLATION_DIR}" "Agent installation directory ${AGENT_INSTALLATION_DIR} removed successfully." "Failed to remove agent installation directory ${AGENT_INSTALLATION_DIR}."

	execCommand "rm ${SYMBOLIC_LINK}" "Symbolic link ${SYMBOLIC_LINK} removed successfully." "Failed to remove symbolic link ${SYMBOLIC_LINK}."

	log "INFO" "" false
	log "INFO" "+---------------------------------------------------------------+" false
	log "INFO" "|                                                               |" false
	log "INFO" "|     OCSInventory Agent has been successfully uninstalled.     |" false
	log "INFO" "|                                                               |" false
	log "INFO" "+---------------------------------------------------------------+" false
}

# Function to prompt for confirmation
prompt_confirmation() {
	echo -n "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? "
	read -r confirm
	log "INFO" "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? $confirm" true
	if [[ "$confirm" =~ ^[yY]?$ ]]; then
		uninstall_agent
	else
		log "INFO" "Uninstallation cancelled." false
	fi
}

# Check for automatic confirmation or prompt the user
if [ "$AUTO_CONFIRM" = "true" ]; then
	uninstall_agent
else
	prompt_confirmation
fi
