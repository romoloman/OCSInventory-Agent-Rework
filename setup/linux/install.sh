#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "The installation script requires elevated privileges, please run as root" >&2
	exit 1
fi

# Constants
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
WORKING_DIRECTORY_EXEC_PATH="/setup/linux"
EXEC_AGENT="/AGENT-LINUX"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent/ocsinventory-agent.log"
STORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_NAME="ocsinventory-agent"
SERVICE_EXEC="/DAEMON-LINUX"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent-ng"

# Function to display usage information
usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  -S, --silent              Enable silent mode (requires --url, --username, --password)"
	echo "  -U, --url URL             URL of the OCS Inventory server (required for silent mode)"
	echo "  -u, --username USERNAME   Username (required for silent mode)"
	echo "  -p, --password PASSWORD   Password (required for silent mode)"
	echo "  -m, --mode MODE           Inventory mode (default: 2 = Remote without template)"
	echo "  -l, --log-level LEVEL     Log level (default: 2 = Info)"
	echo "  -c, --certificate CERT    Path to the certificate file (default: null)"
	echo "  -s, --service             Register the agent as a systemd service"
	echo "  -n, --now                 Run the agent inventory immediately after installation"
	echo "  -h, --help                Display this help message"
	exit 1
}

# Default values
SILENT=false
URL=""
USERNAME=""
PASSWORD=""
INVENTORY_MODE=""
LOG_LEVEL=""
SERVICE=false
NOW=false # if true, we run the agent now with mode 2
CERTIFICATE="null"

# options
SHORT_OPTS="hSnU:u:p:m:l:c:s"
LONG_OPTS="help,silent,now,url:,username:,password:,mode:,log-level:,certificate:,service"

# parse options
PARSED_OPTIONS=$(getopt --options $SHORT_OPTS --longoptions $LONG_OPTS --name "$0" -- "$@")
if [ $? -ne 0 ]; then
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
	-U | --url)
		URL="$2"
		shift 2
		;;
	-u | --username)
		USERNAME="$2"
		shift 2
		;;
	-p | --password)
		PASSWORD="$2"
		shift 2
		;;
	-m | --mode)
		INVENTORY_MODE="$2"
		shift 2
		;;
	-l | --log-level)
		LOG_LEVEL="$2"
		shift 2
		;;
	-c | --certificate)
		CERTIFICATE="$2"
		shift 2
		;;
	-s | --service)
		SERVICE=true
		shift
		;;
	-n | --now)
		NOW=true
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
		echo "Internal error!" >&2
		exit 1
		;;
	esac
done

# Function to check if the parameters are provided
check_parameters() {
	local url="$1"
	local username="$2"
	local password="$3"
	local log_level="$4"
	local inventory_mode="$5"
	local is_silent="$6"

	# check required params in silend mode only
	if [ "$is_silent" = "true" ]; then
		if [ -z "$url" ]; then
			echo "Server URL is required in silent mode (-U, --url)" >&2
			usage
		fi
		if [ -z "$username" ]; then
			echo "Username is required in silent mode (-u, --username)" >&2
			usage
		fi
		if [ -z "$password" ]; then
			echo "Password is required in silent mode (-p, --password)" >&2
			usage
		fi
	fi

	# Check if the log level empty
	if [ -z "$log_level" ]; then
		echo "Log level will be set to 2 by default"
		LOG_LEVEL=2
	else
		# Check if the log level is a number
		if ! echo "$log_level" | grep -qE '^[0-9]+$'; then
			echo "Log level must be a number, using default value 2 (Info)"
			LOG_LEVEL=2
		else
			echo "Log level is set to $log_level"
		fi
	fi

	# Check if the inventory mode empty
	if [ -z "$inventory_mode" ]; then
		echo "Inventory mode will be set to 2 by default (Remote without template)"
		INVENTORY_MODE=2
	else
		# Check if the inventory mode is a number
		if ! echo "$inventory_mode" | grep -qE '^[0-9]+$'; then
			echo "Inventory mode must be a number, using default value 2 (Remote without template)"
			INVENTORY_MODE=2
		else
			echo "Inventory mode is set to $inventory_mode"
		fi
	fi
}

# Function to check if the agent is already installed
check_installed_agent() {
	# Check if any standard agent installation artifacts exist
	if [ -d "$AGENT_INSTALLATION_DIR" ] || [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] || [ -d "$CONFIG_PATH" ] || [ -f "$LOG_PATH" ]; then
		# check if running in silent mode
		if [ "$SILENT" = "true" ]; then
			echo "Existing agent installation detected in silent mode. Automatically uninstalling..."
			# automatically uninstall in silent mode
			sudo sh "${WORKING_DIRECTORY}/uninstall.sh" -y
		else
			# prompt the user in interactive mode
			echo -n "The agent is already installed, do you want to remove it first? ([y]/n) "
			read -r remove_choice
			if [ "$remove_choice" = "y" ] || [ "$remove_choice" = "Y" ] || [ -z "$remove_choice" ]; then
				echo "Uninstalling the existing agent..."
				sudo sh "${WORKING_DIRECTORY}/uninstall.sh" -y
			# if the user chose 'n', we inform them the script will likely overwrite files
			else
				echo "Proceeding with installation without removing the existing one. Files may be overwritten."
			fi
		fi
	fi
}

# Check if the agent is already installed
check_installed_agent

# Function to copy agent contents to /usr/share/ocsinventory-agent
copy_agent_contents() {

	# Define the source directory by navigating three levels up from the script directory
	SOURCE_DIR="$WORKING_DIRECTORY/../../"

	# Create the target directory if it does not exist
	mkdir -p "$AGENT_INSTALLATION_DIR"

	# Copy all the contents from the source directory to the target directory
	cp -r "$SOURCE_DIR"/* "$AGENT_INSTALLATION_DIR"

	chmod +x "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT"
	chmod +x "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$SERVICE_EXEC"

	# Link the exec agent to /usr/bin
	sudo ln -s "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT" "$SYMBOLIC_LINK"

}

# Function to run the executable with provided params
run_executable() {
	local url="$1"
	local username="$2"
	local password="$3"
	local log_level="$4"
	local run_now="$5"
	local certificate="$6"
	local inventory_mode="$7"

	# Construct command for running executable
	command_install="$WORKING_DIRECTORY$EXEC_AGENT -f true -m 0 -p $password -u $username -s $url -l $LOG_PATH -d $STORE_DATA_PATH -v $log_level -c $certificate"
	# echo "Executing command: $command"
	$command_install

	if [ "$run_now" = "true" ]; then
		echo "Running the agent now..."
		command_run="$WORKING_DIRECTORY$EXEC_AGENT -f true -m $inventory_mode -p $password -u $username -s $url -l $LOG_PATH -d $STORE_DATA_PATH -v $log_level -c $certificate"
		$command_run
	fi
}

# Function to register service
register_service() {
	# create service file
	echo "Creating ${SERVICE_NAME} service file..."
	sudo cp "${WORKING_DIRECTORY}/ocsinventory-agent.service" "/etc/systemd/system/${SERVICE_NAME}.service"

	# restart daemon, enable and start service
	echo "Reloading daemon and enabling service"
	sudo systemctl daemon-reload
	sudo systemctl enable ${SERVICE_NAME}.service
	sudo systemctl start ${SERVICE_NAME}.service
	echo "Service Started"
}

# Function to run in silent mode
run_silent() {
	echo
	echo "+----------------------------------------------------------+"
	echo "|                                                          |"
	echo "|   Installing OCS Inventory Agent in silent mode...       |"
	echo "|                                                          |"
	echo "+----------------------------------------------------------+"
	echo

	check_parameters "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$INVENTORY_MODE" true
	copy_agent_contents
	run_executable "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$NOW" "$CERTIFICATE" "$INVENTORY_MODE"

}

# Function to run in interactive mode
run_interactive() {
	echo
	echo "+---------------------------------------------------------------+"
	echo "|                                                               |"
	echo "|   Installing OCS Inventory Agent in interactive mode...       |"
	echo "|                                                               |"
	echo "+---------------------------------------------------------------+"
	echo

	# only prompting if the var has not been set by an arg already
	if [ -z "$URL" ]; then
		echo -n "Enter server URL: "
		read -r URL
	fi
	if [ -z "$USERNAME" ]; then
		echo -n "Enter username: "
		read -r USERNAME
	fi
	if [ -z "$PASSWORD" ]; then
		echo -n "Enter password: "
		read -r PASSWORD
	fi
	if [ -z "$INVENTORY_MODE" ]; then
		echo -n "Enter the inventory mode (default is 2 = Remote without template): "
		read -r INVENTORY_MODE
	fi
	if [ -z "$LOG_LEVEL" ]; then
		echo -n "Enter the log level (default is 2 = Info): "
		read -r LOG_LEVEL
	fi
	if [ "$CERTIFICATE" = "null" ]; then
		echo -n "Enter the certificate path (leave empty if none): "
		read -r cert_input
		if [ -n "$cert_input" ]; then
			CERTIFICATE="$cert_input"
		fi
	fi
	if [ "$SERVICE" = "false" ]; then
		echo -n "Should the agent be registered as a systemd service? ([y]/n):"
		read -r service_choice
		if [ "$service_choice" = "y" ] || [ "$service_choice" = "Y" ] || [ -z "$service_choice" ]; then
			SERVICE=true
		fi
	fi

	if [ "$NOW" = "false" ]; then
		echo -n "Do you want the agent to run immediately after installation? ([y]/n):"
		read -r now_choice
		if [ "$now_choice" = "y" ] || [ "$now_choice" = "Y" ] || [ -z "$now_choice" ]; then
			NOW=true
		fi
	fi

	check_parameters "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$INVENTORY_MODE" false
	copy_agent_contents
	run_executable "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$NOW" "$CERTIFICATE" "$INVENTORY_MODE"

}

# Run in the appropriate mode
if [ "$SILENT" = "true" ]; then
	run_silent
else
	run_interactive
fi

# Check if all are created successfully
if [ -d "$CONFIG_PATH" ] && [ -f "$LOG_PATH" ] && [ -d "$AGENT_INSTALLATION_DIR" ] && [ -f "$SYMBOLIC_LINK" ]; then
	if [ "$SERVICE" = "true" ]; then
		register_service
	fi
	echo
	echo "+------------------------------------------------------------------------------+"
	echo "|   OCS Inventory Agent has been successfully installed and configured.        |"
	echo "|                                                                              |"
	echo "|   Configuration files are located at $CONFIG_PATH"
	echo "|   Log file is located at $LOG_PATH"
	echo "|   Agent data storage is located at $STORE_DATA_PATH"
	echo "|   Agent installation directory is located at $AGENT_INSTALLATION_DIR"
	echo "|                                                                              |"
	echo "|   Please refer to the documentation for more information                     |"
	echo "+------------------------------------------------------------------------------+"
	echo

else
	echo
	echo
	echo "*** ERROR: Installation failed, please check the logs for more information" >&2
	echo
	echo "Installation aborted !" >&2
	exit 1
fi

exit 0
