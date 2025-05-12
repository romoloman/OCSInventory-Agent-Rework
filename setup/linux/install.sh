#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
	echo "Please run the installation as root"
	exit 1
fi

# Constants
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
WORKING_DIRECTORY_EXEC_PATH="/setup/linux"
EXEC_AGENT="/AGENT-LINUX"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent/ocsinventory-agent.log"
STRORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_NAME="ocsinventory-agent"
SERVICE_EXEC="/DAEMON-LINUX"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent-ng"

# Function to display usage information
usage() {
	echo "Usage: $0 [-l Link] [-u USERNAME] [-p PASSWORD] [-m MODE] [-v LOG_LEVEL ] [-c CERTIFICATE] [-s] [-n] [-h]"
	echo "  -l Link             Link of the OCS Inventory NG server"
	echo "  -u USERNAME         Username"
	echo "  -p PASSWORD         Password"
	echo "  -m MODE             Inventory mode"
	echo "  -v LOG_LEVEL        Log level"
	echo "  -c CERTIFICATE      Path to the certificate file"
	echo "  -s                  Service mode (register service)"
	echo "  -n                  Run the agent now"
	echo "  -h			        Display this help message"
	exit 1
}

# Default values
SILENT=false
SERVICE=false
NOW=false # if true, we run the agent now with mode 2
CERTIFICATE="null"

# Parse command-line arguments
while getopts "l:u:p:m:v:c:snh" opt; do
	case ${opt} in
	l) URL=$OPTARG ;;
	u) USERNAME=$OPTARG ;;
	p) PASSWORD=$OPTARG ;;
	m) INVENTORY_MODE=$OPTARG ;;
	v) LOG_LEVEL=$OPTARG ;;
	c) CERTIFICATE=$OPTARG ;;
	s) SERVICE=true ;;
	n) NOW=true ;;
	h) usage ;;
	*) usage ;;
	esac
done

# Function to check if the parameters are provided
check_parameters() {
	local url="$1"
	local username="$2"
	local password="$3"
	local log_level="$4"
	local inventory_mode="$5"

	if [ -z "$url" ]; then
		echo "Server URL is required"
		usage
	fi
	if [ -z "$username" ]; then
		echo "Username is required"
		usage
	fi
	if [ -z "$password" ]; then
		echo "Password is required"
		usage
	fi

	# Check if the log level empty
	if [ -z "$log_level" ]; then
		echo "Log level is set 2 by default"
		LOG_LEVEL=2
	else
		# Check if the log level is a number
		if ! echo "$log_level" | grep -qE '^[0-9]+$'; then
			echo "Log level must be a number, so it is set to the default value 2"
			LOG_LEVEL=2
		else
			echo "Log level is set to $log_level"
		fi
	fi

	# Check if the inventory mode empty
	if [ -z "$inventory_mode" ]; then
		echo "Inventory mode is set 2 by default"
		INVENTORY_MODE=2
	else
		# Check if the inventory mode is a number
		if ! echo "$inventory_mode" | grep -qE '^[0-9]+$'; then
			echo "Inventory mode must be a number, so it is set to the default value 2"
			INVENTORY_MODE=2
		else
			echo "Inventory mode is set to $inventory_mode"
		fi
	fi
}

# Function to check if the agent is alread -ry installed
check_installed_agent() {
	if [ -d "$AGENT_INSTALLATION_DIR" ] || [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] || [ -d "$CONFIG_PATH" ] || [ -f "$LOG_PATH" ]; then
		echo -n "The agent is already installed, do you want to remove it first ? ([y]/n) "
		read -r remove_choice
		if [ "$remove_choice" = "y" ] || [ "$remove_choice" = "Y" ] || [ -z "$remove_choice" ]; then
			echo "Uninstalling the existing agent..."
			sudo sh "${WORKING_DIRECTORY}/uninstall.sh" -y
		fi
	fi
}

# Check if the agent is alread -ry installed
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
	command_install="$WORKING_DIRECTORY$EXEC_AGENT -f true -m 0 -p $password -u $username -s $url -l $LOG_PATH -d $STRORE_DATA_PATH -v $log_level -c $certificate"
	# echo "Executing command: $command"
	$command_install

	if [ "$run_now" = "true" ]; then
		echo "Running the agent now..."
		command_run="$WORKING_DIRECTORY$EXEC_AGENT -f true -m $inventory_mode -p $password -u $username -s $url -l $LOG_PATH -d $STRORE_DATA_PATH -v $log_level -c $certificate"
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
	echo "|  Welcome to OCS Inventory NG Agent in silent mode... !   |"
	echo "|                                                          |"
	echo "+----------------------------------------------------------+"
	echo

	check_parameters "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$INVENTORY_MODE"
	copy_agent_contents
	run_executable "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$NOW" "$CERTIFICATE" "$INVENTORY_MODE"

}

# Function to run in interactive mode
run_interactive() {
	echo
	echo "+---------------------------------------------------------------+"
	echo "|                                                               |"
	echo "|  Welcome to OCS Inventory NG Agent in interactive mode... !   |"
	echo "|                                                               |"
	echo "+---------------------------------------------------------------+"
	echo
	echo -n "Enter server URL: "
	read -r URL
	echo -n "Enter username: "
	read -r USERNAME
	echo -n "Enter password: "
	read -r PASSWORD
	echo -n "Enter the inventory mode (default is 2 = Remote without template): "
	read -r INVENTORY_MODE
	echo -n "Enter the log level (default is 2 = Info): "
	read -r LOG_LEVEL
	echo -n "Enter the certificate path: "
	read -r CERTIFICATE
	echo -n "Do you register the service - agent must be launched automatically ([y]/n)? "
	read -r service_choice
	if [ "$service_choice" = "y" ] || [ "$service_choice" = "Y" ] || [ -z "$service_choice" ]; then
		SERVICE=true
	fi
	echo -n "Do you want to run the agent now ([y]/n)? "
	read -r now_choice
	if [ "$now_choice" = "y" ] || [ "$now_choice" = "Y" ] || [ -z "$now_choice" ]; then
		NOW=true
	fi

	check_parameters "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$INVENTORY_MODE"
	copy_agent_contents
	run_executable "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$NOW" "$CERTIFICATE" "$INVENTORY_MODE"

}

# Check if all required parameters are provided for silent mode
if [ -n "$URL" ] && [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
	SILENT=true
fi

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
	echo "|   OK, OCS Inventory NG Agent for Unix/Linux has been successfully            |"
	echo "|                    installed and configured.                                 |"
	echo "|                                                                              |"
	echo "|   Configuration files are located in /etc/ocsinventory-agent                 |"
	echo "|   Log file is located in /var/log/ocsinventory-agent/ocsinventory-agent.log  |"
	echo "|   Store Data Path is located in /var/lib/ocsinventory-data                   |"
	echo "|   Agent Installation Directory is located in /usr/share/ocsinventory-agent   |"
	echo "|                                                                              |"
	echo "|                                                                              |"
	echo "|   Enjoy OCS Inventory NG Agent ;-)                                           |"
	echo "+------------------------------------------------------------------------------+"
	echo

else
	echo
	echo
	echo "*** ERROR: Install of agent failed, please look at error and fix !"
	echo
	echo "Installation aborted !"
	exit 1
fi

exit 0
