#!/bin/bash
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
# Define default values
DEFAULT_SERVER="http://example.com"
DEFAULT_USERNAME="defaultuser"
DEFAULT_PASSWORD="defaultpassword"
DEFAULT_LOGLEVEL="Info"
DEFAULT_SERVICEMODE="no"
DEFAULT_RUNNOW="no"

# Function to display usage information
usage() {
	echo "Usage: $0 [-h URL] [-u USERNAME] [-p PASSWORD] [-v LOG_LEVEL ] [-l] [-s] [-n] [-h]"
	echo "  -h HOST       host URL of the OCS Inventory NG server"
	echo "  -u USERNAME   Username"
	echo "  -p PASSWORD   Password"
	echo "  -v LOG_LEVEL  Log level"
	echo "  -l            Local mode (do not register service)"
	echo "  -s            Service mode (register service)"
	echo "  -n            Run the agent now"
	exit 1
}

# Default values
SILENT=false
LOCAL=false
SERVICE=false
NOW=false # if true, we run the agent now with mode 2

# Parse command-line arguments
while getopts "h:u:p:v:lsnih" opt; do
	case ${opt} in
	h) URL=$OPTARG ;;
	u) USERNAME=$OPTARG ;;
	p) PASSWORD=$OPTARG ;;
	v) LOG_LEVEL=$OPTARG ;;
	l) LOCAL=true ;;
	s) SERVICE=true ;;
	n) NOW=true ;;
	*) usage ;;
	esac
done

# Change service and now values to yes if the flags are set
if [ "$SERVICE" = "true" ]; then
    SERVICE="yes"
else
    SERVICE="no"
fi

if [ "$NOW" = "true" ]; then
    NOW="yes"
else
    NOW="no"
fi

# Read values from arguments or use defaults
server="${URL:-$DEFAULT_SERVER}"
username="${USERNAME:-$DEFAULT_USERNAME}"
password="${PASSWORD:-$DEFAULT_PASSWORD}"
logLevel="${LOG_LEVEL:-$DEFAULT_LOGLEVEL}"
serviceMode="${SERVICE:-$DEFAULT_SERVICEMODE}"
runNow="${NOW:-$DEFAULT_RUNNOW}"

# Save the configuration to /tmp/installer_config_file.txt
cat <<EOF | sudo tee "/tmp/installer_config.txt" >/dev/null
server=${server}
username=${username}
password=${password}
logLevel=${logLevel}
serviceMode=${serviceMode}
runNow=${runNow}
EOF

# build the package path by navigating one level up from the script directory
SETUP_PATH=$(dirname "$WORKING_DIRECTORY")
PKG_PATH="${SETUP_PATH}/build/OCS Inventory Agent Setup.mpkg"

# Check if the package exists
if [ -f "$PKG_PATH" ]; then
	echo "Package not found: $PKG_PATH"
	exit 1
fi
# Run installer with configuration file
sudo installer -pkg "$PKG_PATH" -target /Applications

exit 0

