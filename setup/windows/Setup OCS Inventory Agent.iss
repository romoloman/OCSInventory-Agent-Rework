#define AppName "OCSInventory Agent"
#define AppVersion "3.0.0"
#define AppPublisher "OCSInventory"
#define AppURL "https//www.ocsinventory.com/"
#define AppExeName "OCSInventory-Agent.exe"
#define ServiceExeName "OCSInventory-Service.exe"
#define AppPath "C:\Users\antoi\source\repos\OCSInventory-NG\OCSInventory-Agent-Rework"

[Setup]
AppId={{652EB54C-0A14-46AF-9F06-3BA7C294AFC9}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
LicenseFile={#AppPath}\setup\windows\media\license.txt
OutputDir=OCSInventory-Agent-Setup
OutputBaseFilename=OCSInventory-Agent-Setup-{#AppVersion}
SetupIconFile={#AppPath}\setup\windows\media\icone_ocs.ico
SetupLogging=yes
SolidCompression=yes
UninstallDisplayIcon={#AppPath}\setup\windows\media\icone_ocs.ico
UninstallLogging=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "{#AppPath}\setup\windows\OCSInventory-Service\bin\Release\net8.0\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#AppPath}\setup\windows\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Code]
var
  INSTALL_AS_A_SERVICE, RUN_NOW: Boolean;
  ConnectionInputPage, ConfigInputPage: TInputQueryWizardPage;
  CheckPage: TWizardPage;
  URL, USERNAME, PASSWORD, CERTIFICATE, STORE_DATA_PATH, CONFIG_PATH, LOG_PATH: String;
  INVENTORY_MODE, LOG_LEVEL: Integer;
  InstallAsAServiceCheckBox, RunNowCheckBox: TNewCheckBox;
  ResultCode: Integer;

function BoolToStr(Value: Boolean): String;
begin
  if Value then
    Result := 'True'
  else
    Result := 'False';
end;

procedure InitializeWizard;
begin
  Log(ExpandConstant('{cm:StartingOCSInventoryAgentSetup}'));

  if WizardSilent then
  begin
    Log(ExpandConstant('{cm:RunningInSilentMode}'));
  end
  else
  begin
    Log(ExpandConstant('{cm:RunningInInteractiveMode}'));
    ConnectionInputPage := CreateInputQueryPage(wpLicense, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'), ExpandConstant('{cm:MandatoryFields}'));

    ConnectionInputPage.Add('* ' + ExpandConstant('{cm:URL}'), False);
    ConnectionInputPage.Add('* ' + ExpandConstant('{cm:Username}'), False);
    ConnectionInputPage.Add('* ' + ExpandConstant('{cm:Password}'), True);
    ConnectionInputPage.Add(ExpandConstant('{cm:Certificate}'), False);

    ConfigInputPage := CreateInputQueryPage(ConnectionInputPage.ID, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'), ExpandConstant('{cm:MandatoryFields}'));

    ConfigInputPage.Add(ExpandConstant('{cm:AgentMode}'), False);
    ConfigInputPage.Add(ExpandConstant('{cm:LogLevel}'), False);

    CheckPage := CreateCustomPage(ConfigInputPage.ID, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'));

    RunNowCheckBox := TNewCheckBox.Create(CheckPage);
    RunNowCheckBox.Parent := CheckPage.Surface;
    RunNowCheckBox.Top := 0;
    RunNowCheckBox.Left := 0;
    RunNowCheckBox.Width := CheckPage.SurfaceWidth;
    RunNowCheckBox.Caption := ExpandConstant('{cm:RunNow}');
    RunNowCheckBox.Checked := True;

    InstallAsAServiceCheckBox := TNewCheckBox.Create(CheckPage);
    InstallAsAServiceCheckBox.Parent := CheckPage.Surface;
    InstallAsAServiceCheckBox.Top := RunNowCheckBox.Top + 50;
    InstallAsAServiceCheckBox.Left := 0;
    InstallAsAServiceCheckBox.Width := CheckPage.SurfaceWidth;
    InstallAsAServiceCheckBox.Caption := ExpandConstant('{cm:InstallAsAService}');
    InstallAsAServiceCheckBox.Checked := True;

    Log(ExpandConstant('{cm:WaitingUserToEnterInputs}'));
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if WizardSilent then
  begin
    Exit;
  end
  else
  begin
    if CurPageID = ConnectionInputPage.ID then
    begin
      if ConnectionInputPage.Values[0] = '' then
      begin
        MsgBox(Format(ExpandConstant('{cm:ErrorMandatoryField}'), [ExpandConstant('{cm:URL}')]), mbError, MB_OK);
        Result := False;
      end
      else if ConnectionInputPage.Values[1] = '' then
      begin
        MsgBox(Format(ExpandConstant('{cm:ErrorMandatoryField}'), [ExpandConstant('{cm:Username}')]), mbError, MB_OK);
        Result := False;
      end
      else if ConnectionInputPage.Values[2] = '' then
      begin
        MsgBox(Format(ExpandConstant('{cm:ErrorMandatoryField}'), [ExpandConstant('{cm:Password}')]), mbError, MB_OK);
        Result := False;
      end
      else
      begin
        Log(Format(ExpandConstant('{cm:ConnectionDetailsValidated}'), [ConnectionInputPage.Values[0], ConnectionInputPage.Values[1]]));
      end;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if WizardSilent then
    begin
      URL := ExpandConstant('{param:URL}');
      USERNAME := ExpandConstant('{param:USERNAME}');
      PASSWORD := ExpandConstant('{param:PASSWORD}');
      CERTIFICATE := ExpandConstant('{param:CERTIFICATE}');
      INVENTORY_MODE := StrToInt64Def(ExpandConstant('{param:MODE}'), 2);
      LOG_LEVEL := StrToInt64Def(ExpandConstant('{param:LOG_LEVEL}'), 2);

      RUN_NOW := (ExpandConstant('{param:NOW}') = 'True');
      INSTALL_AS_A_SERVICE := (ExpandConstant('{param:SERVICE}') = 'True');

      Log(Format(ExpandConstant('{cm:Parameters}'), [URL, USERNAME, CERTIFICATE, INVENTORY_MODE, LOG_LEVEL, BoolToStr(RUN_NOW), BoolToStr(INSTALL_AS_A_SERVICE)]));
    end
    else
    begin
      URL := ConnectionInputPage.Values[0];
      USERNAME := ConnectionInputPage.Values[1];
      PASSWORD := ConnectionInputPage.Values[2];
      CERTIFICATE := ConnectionInputPage.Values[3];
      INVENTORY_MODE := StrToInt64Def(ConfigInputPage.Values[0], 2);
      LOG_LEVEL := StrToInt64Def(ConfigInputPage.Values[1], 2);

      Log(Format(ExpandConstant('{cm:Parameters}'), [URL, USERNAME, CERTIFICATE, INVENTORY_MODE, LOG_LEVEL, BoolToStr(RunNowCheckBox.Checked), BoolToStr(InstallAsAServiceCheckBox.Checked)]));
    end;

    STORE_DATA_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent');
    CONFIG_PATH := STORE_DATA_PATH + '\config.json';
    LOG_PATH := STORE_DATA_PATH + '\ocsinventory-agent.log';
    INSTALL_PATH := ExpandConstant('{app}');
    
    StringChangeEx(STORE_DATA_PATH, '\', '/', True);
    StringChangeEx(CONFIG_PATH, '\', '/', True);
    StringChangeEx(LOG_PATH, '\', '/', True);

    if DirExists(STORE_DATA_PATH) then
    begin
      Log(Format(ExpandConstant('{cm:DataDirectoryExist}'), [CONFIG_PATH]));
    end
    else
    begin
      Log(Format(ExpandConstant('{cm:DataDirectoryDoesNotExist}') , [STORE_DATA_PATH]));
      if CreateDir(STORE_DATA_PATH) then
      begin
        Log(Format(ExpandConstant('{cm:DataDirectoryCreatedSuccessfully}'), [STORE_DATA_PATH]));
      end
      else
      begin
        MsgBox(ExpandConstant('{cm:ErrorCreatingDataDirectory}'), mbError, MB_OK);
      end;
    end;

    if SaveStringToFile(CONFIG_PATH, Format('{"url": "%s", "username": "%s", "password": "%s", "certificate": "%s", "bypass_certificate": false, "log_file": true, "log_level": %d, "mode": %d, "data_directory": "%s", "log_file_path": "%s", "install_directory": "%s"}', [URL, USERNAME, PASSWORD, CERTIFICATE, LOG_LEVEL, INVENTORY_MODE, STORE_DATA_PATH, LOG_PATH, INSTALL_PATH]), false) then
    begin
      Log(Format(ExpandConstant('{cm:ConfigurationFileCreatedSuccessfully}'), [CONFIG_PATH]));
    end
    else
    begin
        MsgBox(ExpandConstant('{cm:ErrorCreatingConfigurationFile}'), mbError, MB_OK);
    end;
    
    if not WizardSilent then
    begin
      if InstallAsAServiceCheckBox.Checked then
      begin
        Log(ExpandConstant('{cm:InstallingOCSInventoryAgentAsAService}'));
        if Exec('sc.exe', 'create "OCSInventory Agent" binpath= "' + ExpandConstant('{app}\{#ServiceExeName}') + '" start= "auto"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          Log(ExpandConstant('{cm:ServiceCreatedSuccessfully}'));
          if Exec('sc.exe', 'description "OCSInventory Agent" "' + ExpandConstant('{cm:ServiceDescription}') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
          begin
            Log(ExpandConstant('{cm:ServiceDescriptionSetSuccessfully}'));
          end
          else
          begin
            MsgBox(ExpandConstant('{cm:ServiceDescriptionFailed}'), mbError, MB_OK);
          end;

          if Exec('sc.exe', 'start "OCSInventory Agent"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
          begin
            Log(ExpandConstant('{cm:ServiceStartedSuccessfully}'));
          end
          else
          begin
            MsgBox(ExpandConstant('{cm:ServiceStartFailed}'), mbError, MB_OK);
          end;
        end
        else
        begin
          MsgBox(ExpandConstant('{cm:ServiceCreateFailed}'), mbError, MB_OK);
        end;
      end
      else if RunNowCheckBox.Checked then
      begin
        if Exec(ExpandConstant('{app}\{#AppExeName}'), '', '', SW_HIDE, ewNoWait, ResultCode) then
        begin
          Log(ExpandConstant('{cm:OCSInventoryAgentStarted}'));
        end
        else
        begin
          MsgBox(ExpandConstant('{cm:FailedToRunOCSInventoryAgent}'), mbError, MB_OK);
        end;
      end;
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if Exec('sc.exe', 'stop "OCSInventory Agent"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if Exec('sc.exe', 'delete "OCSInventory Agent"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        Log(ExpandConstant('{cm:ServiceDeletedSuccessfully}'));
      end
      else
      begin
        MsgBox(ExpandConstant('{cm:ServiceDeleteFailed}'), mbError, MB_OK);
      end;
    end
    else
    begin
      MsgBox(ExpandConstant('{cm:ServiceStopFailed}'), mbError, MB_OK);
    end;

    if DirExists(STORE_DATA_PATH) then
    begin
      if RemoveDir(STORE_DATA_PATH) then
      begin
        Log(Format(ExpandConstant('{cm:DataDirectoryRemovedSuccessfully}'), [STORE_DATA_PATH]));
      end
      else
      begin
        MsgBox(Format(ExpandConstant('{cm:FailedToRemoveDataDirectory}'), [STORE_DATA_PATH]), mbError, MB_OK);
      end;
    end;
  end;
end;

[CustomMessages]
// Custom messages for the setup wizard
AgentConfigurationPageTitle=Agent configuration
AgentConfigurationPageDescription=Please specify your own agent settings.
MandatoryFields=* Required fields are marked with an asterisk.

french.AgentConfigurationPageTitle=Configuration de l'agent
french.AgentConfigurationPageDescription=Veuillez spécifier vos propres paramètres d'agent.
french.MandatoryFields=* Les champs obligatoires sont marqués d'un astérisque.


// Messages for the input fields
URL=URL
Username=Username
Password=Password
Certificate=Certificate
AgentMode=Agent mode
LogLevel=Log level
RunNow=Run the agent now
InstallAsAService=Install agent as a service

french.URL=URL
french.Username=Nom d'utilisateur
french.Password=Mot de passe
french.Certificate=Certificat
french.AgentMode=Mode d'agent
french.LogLevel=Niveau de journalisation
french.RunNow=Exécuter l'agent maintenant
french.InstallAsAService=Installer l'agent en tant que service

// Messages for the logs handling
StartingOCSInventoryAgentSetup=Starting OCS Inventory Agent Setup...
RunningInSilentMode=Running in silent mode.
RunningInInteractiveMode=Running in interactive mode.
WaitingUserToEnterInputs=Waiting for user to enter inputs...
ErrorMandatoryField=The field %s is mandatory.
ConnectionDetailsValidated=Connection details validated: URL: %s, Username: %s, Password: *****
Parameters=Parameters: URL: %s, Username: %s, Password: *****, Certificate: %s, Inventory Mode: %d, Log Level: %d, Run Now: %s, Install as a Service: %s
DataDirectoryExist=Data directory exists: %s
DataDirectoryDoesNotExist=Data directory does not exist: %s
DataDirectoryCreatedSuccessfully=Data directory created successfully: %s
ConfigurationFileCreatedSuccessfully=Configuration file created successfully: %s
ErrorCreatingDataDirectory=Error creating data directory.
ErrorCreatingConfigurationFile=Error creating configuration file.
InstallingOCSInventoryAgentAsAService=Installing OCS Inventory Agent as a service...
ServiceCreatedSuccessfully=Service created successfully.
ServiceDescription=Service starting periodically OCSInventory Agent for Windows.
ServiceDescriptionSetSuccessfully=Service description set successfully.
ServiceDescriptionFailed=Failed to set service description.
ServiceStartedSuccessfully=Service started successfully.
ServiceStartFailed=Failed to start service.
ServiceCreateFailed=Failed to create service.
OCSInventoryAgentStarted=OCS Inventory Agent started.
FailedToRunOCSInventoryAgent=Failed to run OCS Inventory Agent.
ErrorCreatingConfigurationFile=Error creating configuration file.
ServiceDeletedSuccessfully=Service deleted successfully.
ServiceDeleteFailed=Failed to delete service.
ServiceStopFailed=Failed to stop service.
DataDirectoryRemovedSuccessfully=Data directory removed successfully: %s
FailedToRemoveDataDirectory=Failed to remove data directory: %s

french.StartingOCSInventoryAgentSetup=Début de l'installation de l'agent OCS Inventory...
french.RunningInSilentMode=Exécution en mode silencieux.
french.RunningInInteractiveMode=Exécution en mode interactif.
french.WaitingUserToEnterInputs=En attente de l'utilisateur pour entrer les paramètres...
french.ErrorMandatoryField=Le champ %s est obligatoire.
french.ConnectionDetailsValidated=Détails de connexion validés : URL : %s, Nom d'utilisateur : %s, Mot de passe : *****
french.Parameters=Paramètres : URL : %s, Nom d'utilisateur : %s, Mot de passe : *****, Certificat : %s, Mode d'inventaire : %d, Niveau de journalisation : %d, Exécuter maintenant : %s, Installer en tant que service : %s
french.DataDirectoryExist=Le répertoire de données existe : %s
french.DataDirectoryDoesNotExist=Le répertoire de données n'existe pas : %s
french.DataDirectoryCreatedSuccessfully=Répertoire de données créé avec succès : %s
french.ConfigurationFileCreatedSuccessfully=Fichier de configuration créé avec succès : %s
french.ErrorCreatingDataDirectory=Erreur lors de la création du répertoire de données.
french.ErrorCreatingConfigurationFile=Erreur lors de la création du fichier de configuration.
french.InstallingOCSInventoryAgentAsAService=Installation de l'agent OCS Inventory en tant que service...
french.ServiceCreatedSuccessfully=Service créé avec succès.
french.ServiceDescription=Service démarrant périodiquement l'agent OCSInventory pour Windows.
french.ServiceDescriptionSetSuccessfully=Description du service définie avec succès.
french.ServiceDescriptionFailed=Échec de la définition de la description du service.
french.ServiceStartedSuccessfully=Service démarré avec succès.
french.ServiceStartFailed=Échec du démarrage du service.
french.ServiceCreateFailed=Échec de la création du service.
french.OCSInventoryAgentStarted=Agent OCS Inventory démarré.
french.FailedToRunOCSInventoryAgent=Échec de l'exécution de l'agent OCS Inventory.
french.ErrorCreatingConfigurationFile=Erreur lors de la création du fichier de configuration.
french.ServiceDeletedSuccessfully=Service supprimé avec succès.
french.ServiceDeleteFailed=Échec de la suppression du service.
french.ServiceStopFailed=Échec de l'arrêt du service.
french.DataDirectoryRemovedSuccessfully=Répertoire de données supprimé avec succès : %s
french.FailedToRemoveDataDirectory=Échec de la suppression du répertoire de données : %s