# Getting started

## Table of Contents
- [Getting started](#getting-started)
  - [Table of Contents](#table-of-contents)
  - [Step 1: Flutter installation](#step-1-flutter-installation)
    - [Download Flutter packages](#download-flutter-packages)
    - [Add Flutter application to path](#add-flutter-application-to-path)
  - [Step 2: Clone of the project](#step-2-clone-of-the-project)
  - [Step 3: Getting dependencies](#step-3-getting-dependencies)
  - [Step 4: Installing the Agent](#step-4-installing-the-agent)
    - [Installing the agent on Linux](#installing-the-agent-on-linux)
      - [1. Linux Compilation](#1-linux-compilation)
      - [2. Installing the Linux agent non-interactively](#2-installing-the-linux-agent-non-interactively)
      - [3. Installing the Linux agent interactively](#3-installing-the-linux-agent-interactively)
      - [4. Additionnal information for Linux](#4-additionnal-information-for-linux)
    - [Installing the agent on Windows](#installing-the-agent-on-windows)
      - [1. Windows Compilation](#1-windows-compilation)
      - [2. Create your own Windows package](#2-create-your-own-windows-package)
      - [3. Installing the Windows agent non-interactively](#3-installing-the-windows-agent-non-interactively)
      - [4. Installing the Windows agent interactively](#4-installing-the-windows-agent-interactively)
      - [5. Additionnal information for Windows](#5-additionnal-information-for-windows)
    - [Installing the agent on MacOS](#installing-the-agent-on-macos)
      - [1. MacOS Compilation](#1-macos-compilation)
      - [2. Create your own MacOS package](#2-create-your-own-macos-package)
      - [3. Installing the MacOS agent non-interactively](#3-installing-the-macos-agent-non-interactively)
      - [4. Installing the MacOS agent interactively](#4-installing-the-macos-agent-interactively)
      - [5. Additionnal information for MacOS](#5-additionnal-information-for-macos)
  - [Step 5: Agent configuration](#step-5-agent-configuration)
    - [Linux and macos](#linux-and-macos)
    - [Windows](#windows)
    - [SSL](#ssl)
  - [Step 6: Uninstalling the agent](#step-6-uninstalling-the-agent)
  - [Step 7: Troubleshooting](#step-7-troubleshooting)

## Step 1: Flutter installation

### Download Flutter packages

Begin to download the Flutter package by clicking on the big blue button in `Manual install` section on these websites:

- [Linux Installation](https://docs.flutter.dev/get-started/install/linux)
- [MacOS Installation](https://docs.flutter.dev/get-started/install/macos/desktop?tab=download)
- [Windows Installation](https://docs.flutter.dev/get-started/install/windows/desktop?tab=download)

### Add Flutter application to path

- Linux:

```text
echo 'export PATH="$PATH:<path_to_flutter_directory>/flutter/bin"' >> $HOME/.bashrc
```

- MacOS:

```text
echo 'export PATH="$PATH:<path_to_flutter_directory>/flutter/bin"' >> ~/.zshenv
```

## Step 2: Clone of the project

```text
git clone https://github.com/OCSInventory-NG/OCSInventory-Agent-Rework.git
```

or with SSH

```text
git clone git@github.com:OCSInventory-NG/OCSInventory-Agent-Rework.git
```

## Step 3: Getting dependencies

Go to the agent directory and run this command :

```text
flutter pub get
```

## Step 4: Installing the Agent

### Installing the agent on Linux

You will find below how to install OCS Inventory agent on linux

#### 1. Linux Compilation

Go to the linux setup directory: `/setup/linux/`
You need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```text
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o ocsinventory-agent
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o ocsinventory-service
```

Ensure that you have something like this:

```text
├── ocsinventory-agent
├── ocsinventory-service
├── install.sh
└── uninstall.sh
```

#### 2. Installing the Linux agent non-interactively

To install the agent in non-interactive mode, you have to run the linux `install.sh` script with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `install.sh` script arguments:

- -l : set link of the OCS Inventory NG server
- -u : set username
- -p : set password
- -m : set inventory mode
- -v : set level of the log
- -s : set service mode (register service)
- -n : set to run the agent now
- -c : set certificate path

For example, if you want to install OCS Inventory Agent in non-interactive mode and set server adress, set password,set inventory mode, set username, set log level, register the service and run the agent now, you have to run this command:

```text
sudo sh install.sh -l Server_ip_and_port -u username -p password -m 2 -v 3 -s -n -c -c /path of the certificate/cert.pem
```

#### 3. Installing the Linux agent interactively

To install the agent in interactive mode, you have to run the `install.sh` script with root privileges.
If the agent configuration is already exist, it will ask you to remove it before installing the agent.

```text
Enter server URL:

Enter username:

Enter password:

Enter the inventory mode (default is 2 = Remote without template):

Enter the log level (default is 2 = Info):

Enter the certificate path:

Do you register the service - agent must be launched automatically (y/n)?

Do you want to run the agent now (y/n)?
```
For the server URL field, the expected URL is `http://<Server ip:port>`

#### 4. Additionnal information for Linux

- The content of the agent is stored in `/usr/share/ocsinventory-agent` and a symbolic link is created with `/usr/bin/ocsinventory-agent-ng`, so you can run with root privileges

For example, if you want to run the agent and set log level to verbose, you have to run this command:

```text
sudo ocsinventory-agent-ng -v 3
```

- If you set service, it will be `/etc/systemd/system/ocsinventory-agent.service`

- This is a list of all available agent arguments:
  - -f (--log_file) : Enable or disable the log file (if needed)
  - -m (--mode) : Agent execution mode (if needed)
  - -p (--password) : Password (if needed)
  - -t (--token) : Token (if needed)
  - -u (--username) : Username (if needed)
  - -s (--url) : URL to the OCS server (if needed)
  - -d (--data_directory) : Path to the inventory data (if needed)
  - -l (--log_file_path) : Path to the log file (if needed)
  - -v (--log_level) : Log level (if needed)
  - -c (--certificate) : Certificate path

### Installing the agent on Windows

#### 1. Windows Compilation

Go to the linux setup directory: `/setup/windows/`
You need to download `NSSM - the Non-Sucking Service Manager` for handling services

- NSSM Installation last release

  Extract the file, navigate until win64 folder and copy nssm.exe file into your windows setup folder `/setup/windows/`

After adding the NSSM executable file in the setup directory, you need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```text
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o ocsinventory-agent.exe
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o ocsinventory-service.exe
```

Ensure that you have something like this:

```text
├── ocsinventory-agent.exe
├── ocsinventory-service.exe
├── Setup OCS Inventory Agent.iss
└── nssm.exe
```

#### 2. Create your own Windows package

You can create your package (if needed) with Inno setup by using `Setup OCS Inventory Agent.iss` script

- Download and Install Inno Setup. You can download it from [here](https://jrsoftware.org/isinfo.php).
- Run Inno Setup and open the `Setup OCS Inventory Agent.iss` script
- Set up the script, specifying the `Agent path`
- Build the package using Inno Setup's build feature
- The resulting installer will be created in `/setup/windows/` directory

For example, if you want to create your own package, you need to adjust the agent path according to your local setup like this:

```text
#define AgentPath "path where your agent are located\OCSInventory-Agent-Rework"
```

#### 3. Installing the Windows agent non-interactively

To install the agent in non-interactive mode, you have to run the `OCS-NG` with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `OCS-NG` script arguments:

- /VERYSILENT : run in silent mode
- LOG="\path to store\setup.log" : log file of the installation process
- /URL=Server ip and port : link of the OCS Inventory NG server
- /USERNAME=username : set username
- /PASSWORD=password : set password
- /LOGLEVEL=3 : set level of the log
- /SERVICE=True : set service mode (register service)
- /NOW=True : set to run the agent now
- /CERTIFICATE="\path of the certificate\cert.pem" : set certificate path

For example, if you want to install OCS Inventory Agent in non-interactive mode and run in silent mode, log installation process, set server adress, set password, set username, set log level to verbose, register the service and run the agent now, you have to run this command:

```text
mysetup-agent.exe /VERYSILENT /LOG="C:\path to store\setup.log" /URL=Server_ip_and_port /USERNAME=username /PASSWORD=password /LOCAL=False /SERVICE=True /NOW=True /LOGLEVEL=3 /CERTIFICATE="\path of the certificate\cert.pem"
```

#### 4. Installing the Windows agent interactively

To install the agent in interactive mode, you have to run the `OCS-NG` and set all configuration fields.

#### 5. Additionnal information for Windows

- The is installed in `C:\Program Files\OCS Inventory AGENT`

For example, if you want to run the agent and set log level to verbose, you have to run this command:

- If you set service, it will be in service and named `OCSInventory-Agent`

- This is a list of all available agent arguments:
  - -f (--log_file) : Enable or disable the log file
  - -m (--mode) : Agent execution mode
  - -p (--password) : Password
  - -t (--token) : Token
  - -u (--username) : Username
  - -s (--url) : URL to the OCS server
  - -d (--data_directory) : Path to the inventory data
  - -l (--log_file_path) : Path to the log file
  - -v (--log_level) : Log level
  - -c (--certificate) : Certificate path

### Installing the agent on MacOS

#### 1. MacOS Compilation

Go to the linux setup directory: `/setup/macos/`
You need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```text
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o ocsinventory-agent
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o ocsinventory-service
```

#### 2. Create your own MacOS package

You can create your package (if needed) with Xcode and Package applications.

- Build `config-agent-ocs` and copy the bundle file into `OCS Inventory Agent setup` directory
- Build `ocsng_app-xcode` to create OCS-NG pkg and ocscontact. Ensure the Scheme is correct to build each of them
- Build `OCS Inventory Agent setup` to create installation package

Ensure that you have something like this:

```text
├── AUTHORS
├── Changes
├── ocsinventory-agent
├── ocsinventory-service
├── LICENCE.txt
├── OCS Inventory Agent setup
│   ├── build
│   │   └── OCS Inventory Agent Setup.mpkg
│   ├── config-agent-ocs.bundle
│   ├── OCS Inventory Agent.pkgproj
│   └── scripts
├── ocsng_app-xcode
│   ├── build
│   │   └── build
│   │       └── ocscontact
│   │       └── OCS-NG
│   ├── en.lproj
│   ├── ...
├── README.md
├── scripts
├── setup plugins
│ └── config-agent-ocs
└── THANKS
```

#### 3. Installing the MacOS agent non-interactively

To install the agent in non-interactive mode, you have to run the MacOS `install.sh` script with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `install.sh` script arguments:

- -l : set link of the OCS Inventory NG server
- -u : set username
- -p : set password
- -v : set level of the log
- -s : set service mode (register service)
- -n : set to run the agent now
- -c : set certificate path

For example, if you want to install OCS Inventory Agent in non-interactive mode and set server adress, set password, set username, set log level, register the service and run the agent now, you have to run this command:

```text
sudo sh install.sh -l Server_ip_and_port -u username -p password -v 3 -s -n -c -c /path of the certificate/cert.pem
```

#### 4. Installing the MacOS agent interactively

To install the agent in interactive mode, you have to run the `OCS Inventory Agent.mpkg` package and set all configuration fields.

#### 5. Additionnal information for MacOS

- The is installed in `/Applications/OCS-NG`

- If you set up the service, it will be in `/Library/LaunchDaemons/org.ocsinventory.agent.plist`

## Step 5: Agent configuration

### Linux and macos

- Configuration directory : `/etc/ocsinventory-agent`
- Log file in directory : `/var/log/ocsinventory-agent/ocsinventory-agent.log`
- Data inventories : `/var/lib/ocsinventory-data`

### Windows

- Configuration directory, log file and data inventories are in the same directory : `C:\ProgramData\Agent-OCS`

After installing the agent, there is a config forlder and the file `inventory.json` inside.

In this file, there are properties to configure the agent:

|      Property      |                                                                                        Description                                                                                        |
|:------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
|   data_directory   |                                                                     Folder where the agent will store inventory data.                                                                     |
|     log_level      |                                                                      0: Error 1: Warning 2: Info (default) 3 Verbose                                                                      |
|      log_file      |                   Default to false, the logs will be written in the terminal you'r using. Set to true, you'll need to specify a log file where you want to write logs.                    |
|   log_file_path    |               This property is to set the log file path. Only define it if you put log_file to true.<br>**Warning**: It will not create the file. You'll need to create it.               |
|        mode        | This is the working mode property of the agent, there is 5 modes: 0- Installation mode 1-Remote with template 2- Remote without template 3- Local with template 4- Local without template |
|      password      |                                                By default in remote inventory mode, set the password to connect to the backend server api.                                                |
|       token        |                                                  Will be automatically replace to store the retreived token from the backend server api.                                                  |
|      username      |                                                By default in remote inventory mode, set the username to connect to the backend server api.                                                |
|        url         |                                                                                  Backend server api url.                                                                                  |
|    certificate     |                                                                      specify the path to the certificate file (.pem)                                                                      |
| bypass_certificate |                                                                    Bypass certificate verification (false by default)                                                                     |

```text
{
    "log_file": true,
    "mode": 2,
    "password": "password",
    "token": "token value",
    "username": "username",
    "url": "Server ip and port",
    "data_directory": "/var/lib/ocsinventory-data",
    "log_file_path": "/var/log/ocsinventory-agent/ocsinventory-agent.log",
    "log_level": 3,
    "certificate": "/certificate path/file_name.pem"
    "bypass_certificate": false
}
```

### SSL

- HTTP

If your OCS Inventory backend is running with the HTTP protocol, you do not need a certificate file to install the agent.

- HTTPS

If your OCS Inventory backend is running with the HTTPS protocol, you must have a certificate file, even if it is self-signed, to install the agent.

You can bypass SSL certificate verification (if the certificate is self-signed) by running the agent with the `-b true` option or by setting the `bypass_certificate` value to true in the configuration file.

## Step 6: Uninstalling the agent

- Linux Agent: To uninstall the Linux agent,
navigate to `/usr/share/ocsinventory-agent/setup/linux/` and execute the `uninstall.sh` script with root privileges.
- Windows Agent: To uninstall the Windows agent, go to `C:\Program Files\OCS Inventory Agent` and run the `uninstall application` executable.
- MacOS Agent: To uninstall the macOS agent, navigate to `/Applications/OCS-NG.app/Contents/Resources/` and execute the `uninstaller.sh` script with root privileges.

## Step 7: Troubleshooting

If you encounter any issues during the installation or usage of the OCS Inventory Agent, here are some troubleshooting steps you can follow:

1. Check the log files: The agent logs can provide valuable information about any errors or issues. You can find the log files in the `/var/log/ocsinventory-agent/` directory on Linux, `C:\Program Files\OCS Inventory AGENT\logs` directory on Windows, and `/Applications/OCS-NG/logs` directory on macOS.

2. Verify the server URL: Make sure that the server URL you provided is correct and accessible. Double-check for any typos or network connectivity issues.

3. Check the credentials: Ensure that the username and password you provided are correct and have the necessary permissions to access the backend server API.

4. Verify the API URL: Double-check the API URL to ensure it is accurate and points to the correct backend server.

5. Restart the agent: Sometimes, restarting the agent can resolve certain issues.
You can do this by running the appropriate command for your operating system: `sudo systemctl restart ocsinventory-agent`
on Linux,`C:\Program Files\OCS Inventory Agent\setup\windows\nssm.exe stop OCSInventory-Agent` followed by `C:\Program Files\OCS Inventory Agent\setup\windows\nssm.exe start OCSInventory-Agent`
on Windows, and `sudo launchctl unload /Library/LaunchDaemons/org.ocsinventory.agent.plist` followed by `sudo launchctl load /Library/LaunchDaemons/org.ocsinventory.agent.plist` on macOS.
