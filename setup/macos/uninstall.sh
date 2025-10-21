#!/bin/bash

log() {
	local message="$1"
	local only_file="$2"

	if [ "$SILENT" = false ]; then
		if [ "$only_file" = false ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") $message" | tee -a "${WORKING_DIRECTORY}/uninstall.log"
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") $message" >>"${WORKING_DIRECTORY}/uninstall.log"
		fi
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") $message" >>"${WORKING_DIRECTORY}/uninstall.log"
	fi
}

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  -S, --silent          Enable silent mode"
	echo "  -D, --hard-delete     Remove configs, log files and data directory"
	echo "  -y, --yes             Automatically confirm uninstallation without prompting"
	echo "  -h, --help            Display this help message"
	exit 1
}

execCommand() {
	local command="$1"
	local successMessage="$2"
	local errorMessage="$3"

	if $command >/dev/null 2>/dev/null; then
		log "$successMessage" false
	else
		log "$errorMessage" false
	fi
}

get_path() {
	LOG_FILE_PATH=$(sed -n 's/.*"log_file_path": "\([^"]*\)".*/\1/p' "${CONFIG_PATH}/config.json" 2>/dev/null)
	DATA_PATH=$(sed -n 's/.*"data_directory": "\([^"]*\)".*/\1/p' "${CONFIG_PATH}/config.json" 2>/dev/null)
}

legacy_check() {
	if [ -f "${CONFIG_PATH}/modules.conf" ] || [ -f "${CONFIG_PATH}/ocsinventory-agent.cfg" ]; then
		# if interactive AND hard delete, ask use to confirm removal. if yes, log that files WIIL be deleted (later in the script), if not, exit and log for user to remove the legacy agent
		if [ "$SILENT" = false ] && [ "$HARD_DELETE" = true ]; then
			log "Detected legacy agent configuration files in ${CONFIG_PATH}. Proceeding with uninstallation will remove legacy files. Do you want to continue? ([y]/n)" false
			read -r confirm
			if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || [ "$confirm" = "" ]; then
				log "Proceeding. Legacy agent configuration files will be removed during uninstallation." false
			else
				log "Uninstallation cancelled." false
				exit 1
			fi
		fi
		# if silent AND hard delete: log detection and specify the files will be deleted
		if [ "$SILENT" = true ] && [ "$HARD_DELETE" = true ]; then
			log "Detected legacy agent configuration files in ${CONFIG_PATH}. Legacy files will be removed during uninstallation." false
		fi
	fi
}

uninstall_agent() {
	if [ "$SILENT" = true ]; then
		log "+-----------------------------------------------------------+" false
		log "|                                                           |" false
		log "|     Uninstalling OCSInventory Agent in silent mode...     |" false
		log "|                                                           |" false
		log "+-----------------------------------------------------------+" false
		log "" false
	else
		log "+----------------------------------------------------------------+" false
		log "|                                                                |" false
		log "|     Uninstalling OCSInventory Agent in interactive mode...     |" false
		log "|                                                                |" false
		log "+----------------------------------------------------------------+" false
		log "" false
	fi

	get_path

	# launchDaemon exists, uninstall
	if launchctl list | grep -q ${SERVICE_LABEL}; then
		log "LaunchDaemon ${SERVICE_LABEL} exists, proceeding with uninstallation." false

		execCommand "launchctl bootout system /Library/LaunchDaemons/${SERVICE_LABEL}.plist" "LaunchDaemon ${SERVICE_LABEL} stopped successfully." "Failed to stop LaunchDaemon ${SERVICE_LABEL}. It may not be running."

		execCommand "rm /Library/LaunchDaemons/${SERVICE_LABEL}.plist" "LaunchDaemon file /Library/LaunchDaemons/${SERVICE_LABEL}.plist removed successfully." "Failed to remove LaunchDaemon file /Library/LaunchDaemons/${SERVICE_LABEL}.plist."
	else
		log "LaunchDaemon ${SERVICE_LABEL} does not exist. Skipping LaunchDaemon uninstallation." false
	fi

	if [ "$HARD_DELETE" = true ]; then

		legacy_check

		if [ -f "${LOG_FILE_PATH}" ]; then
			log "Log file ${LOG_FILE_PATH} exists, proceeding with removal." false
			execCommand "rm ${LOG_FILE_PATH}" "Log file ${LOG_FILE_PATH} removed successfully." "Failed to remove log file ${LOG_FILE_PATH}."
		else
			log "Log file does not exist, skipping removal." false
		fi

		if [ -d "${DATA_PATH}" ]; then
			log "Data directory ${DATA_PATH} exists, proceeding with removal." false
			execCommand "rm -r ${DATA_PATH}" "Data directory ${DATA_PATH} removed successfully." "Failed to remove data directory ${DATA_PATH}."
		else
			log "Data directory does not exist, skipping removal." false
		fi

		if [ -d "${CONFIG_PATH}" ]; then
			log "Configuration directory ${CONFIG_PATH} exists, proceeding with removal." false
			execCommand "rm -r ${CONFIG_PATH}" "Configuration directory ${CONFIG_PATH} removed successfully." "Failed to remove configuration directory ${CONFIG_PATH}."
		else
			log "Configuration directory does not exist, skipping removal." false
		fi
	fi

	if [ -f "${AGENT_DIR}${AGENT_EXEC}" ]; then
		log "Agent binary ${AGENT_DIR}${AGENT_EXEC} exists, proceeding with removal." false
		execCommand "rm ${AGENT_DIR}${AGENT_EXEC}" "Agent binary ${AGENT_DIR}${AGENT_EXEC} removed successfully." "Failed to remove agent binary ${AGENT_DIR}${AGENT_EXEC}."
	else
		log "Agent binary does not exist, skipping removal." false
	fi

	log "" false
	log "+---------------------------------------------------------------+" false
	log "|                                                               |" false
	log "|     OCSInventory Agent has been successfully uninstalled.     |" false
	log "|                                                               |" false
	log "+---------------------------------------------------------------+" false
}

prompt_confirmation() {
	echo -n "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? "
	read -r confirm
	case "$confirm" in
	"" | "y" | "Y")
		uninstall_agent
		;;
	*)
		log "Uninstallation cancelled." false
		;;
	esac
}

if [ "$(id -u)" != "0" ]; then
	log "The uninstallation script requires elevated privileges, please run as root" false
	exit 1
fi

WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
CONFIG_PATH="/etc/ocsinventory-agent"
AGENT_DIR="/usr/local/bin"
AGENT_EXEC="/ocsinventory-cli"
DATA_PATH="/var/lib/ocsinventory-data"
LOG_FILE_PATH="/var/log/ocsinventory-agent.log"
SERVICE_LABEL="com.ocsinventory.agent"

SILENT=false
HARD_DELETE=false
AUTO_CONFIRM=false

# arg parse
while [[ $# -gt 0 ]]; do
	case "$1" in
	-S | --silent)
		AUTO_CONFIRM=true
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
	*)
		log "Unknown argument: $1" false
		usage
		;;
	esac
done

if [ "$AUTO_CONFIRM" = "true" ]; then
	uninstall_agent
else
	prompt_confirmation
fi
