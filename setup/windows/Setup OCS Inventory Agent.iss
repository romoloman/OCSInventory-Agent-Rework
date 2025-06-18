#define AppName "OCSInventory Agent"
#define AppVersion "3.0.0"
#define AppPublisher "OCSInventory"
#define AppURL "http//www.ocsinventory.com/"
#define AppExeName "agent-windows.exe"
#define AppPath "Path_of_your_agent\OCSInventory-Agent"

[Setup]
AppId={{652EB54C-0A14-46AF-9F06-3BA7C294AFC9}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
LicenseFile={#AppPath}\setup\windows\media\license.txt
OutputDir=OCSInventory-Agent-Setup
OutputBaseFilename=OCSInventory-Agent-Setup-{#AppVersion}
SetupIconFile={#AppPath}\setup\windows\media\icone_ocs.ico
SolidCompression=yes
UninstallDisplayIcon={#AppPath}\setup\windows\media\icone_ocs.ico
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "{#AppPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#AppPath}\setup\windows\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Code]
var
  silent: Boolean;
  ConnectionInputPage, ConfigInputPage: TInputQueryWizardPage;
  CheckPage: TWizardPage;
  URL, USERNAME, PASSWORD, CERTIFICATE, STORE_DATA_PATH, CONFIG_PATH, LOG_PATH: String;
  INVENTORY_MODE, LOG_LEVEL: Integer;
  InstallAsAServiceCheckBox, RunNowCheckBox: TNewCheckBox;
  ResultCode: Integer;

function Logger(LogType, LogMessage: String): Boolean;
var
  LogTime: String;
begin
  Result := True;
  LogTime := GetDateTimeString('dd/mm/yyyy hh:nn:ss', '-', ':');
  LogType := UpperCase(LogType);

  Log(Format('[%s] [%s] %s', [LogTime, LogType, LogMessage]));
  SaveStringToFile(ExpandConstant('{src}/install.log'), Format('[%s] [%s] %s', [LogTime, LogType, LogMessage]) + #13#10, true); // #13#10 = NewLine
end;

procedure InitializeWizard;
begin
  Logger('info', 'Starting OCSInventory Agent setup...');

  Silent := (Pos('/SILENT', GetCmdTail) > 0)

  if Silent then
  begin
    Logger('info', 'Running in silent mode');

    URL := GetCmdParam('/URL');
    USERNAME := GetCmdParam('/USERNAME');
    PASSWORD := GetCmdParam('/PASSWORD');
    CERTIFICATE := GetCmdParam('/CERTIFICATE');
    INVENTORY_MODE := StrToInt64Def(GetCmdParam('/INVENTORY_MODE'), 2);
    LOG_LEVEL := StrToInt64Def(GetCmdParam('/LOG_LEVEL'), 2);

    RUN_NOW_CHECKBOX := GetCmdParam('/RUN_NOW');
    INSTALL_AS_A_SERVICE_CHECKBOX := GetCmdParam('/INSTALL_AS_A_SERVICE');
    if RUN_NOW_CHECKBOX = '' then
      RunNowCheckBox.Checked := True
    else
      RunNowCheckBox.Checked := StrToBoolDef(RUN_NOW_CHECKBOX, True);
    if INSTALL_AS_A_SERVICE_CHECKBOX = '' then
      InstallAsAServiceCheckBox.Checked := True
    else
      InstallAsAServiceCheckBox.Checked := StrToBoolDef(INSTALL_AS_A_SERVICE_CHECKBOX, True);

    STORE_DATA_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent');
    CONFIG_PATH := STORE_DATA_PATH + '\config.json';
    LOG_PATH := STORE_DATA_PATH + '\ocsinventory-agent.log';

    Logger('info', 'Silent mode parameters: URL=' + URL + ', USERNAME=' + USERNAME + ', PASSWORD=******, CERTIFICATE=' + CERTIFICATE + ', INVENTORY_MODE=' + IntToStr(INVENTORY_MODE) + ', LOG_LEVEL=' + IntToStr(LOG_LEVEL));
  end
  else
  begin
    Logger('info', 'Running in normal mode');
    ConnectionInputPage := CreateInputQueryPage(wpLicense, ExpandConstant('{cm:AgentConfigurationPageTitle}'), ExpandConstant('{cm:AgentConfigurationPageDescription}'), ExpandConstant('{cm:MandatoryFields}'));

    ConnectionInputPage.Add('* ' + ExpandConstant('{cm:URL}'), False);
    ConnectionInputPage.Add('* ' + ExpandConstant('{cm:Username}'), False);
    ConnectionInputPage.Add('* ' + ExpandConstant('{cm:Password}'), False);
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

    Logger('info', 'Waiting user to enter inputs...');
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if CurPageID = ConnectionInputPage.ID then
  begin
    if ConnectionInputPage.Values[0] = '' then
    begin
      if not Silent then
      begin
        MsgBox(ExpandConstant('{cm:ErrorMandatoryField, {cm:URL}}'), mbError, MB_OK);
      end;
      Logger('error', 'Connection details validation failed: URL is empty');
      Result := False;
    end
    else if ConnectionInputPage.Values[1] = '' then
    begin
      if not Silent then
      begin
        MsgBox(ExpandConstant('{cm:ErrorMandatoryField, {cm:Username}}'), mbError, MB_OK);
      end;
      Logger('error', 'Connection details validation failed: Username is empty');
      Result := False;
    end
    else if ConnectionInputPage.Values[2] = '' then
    begin
      if not Silent then
      begin
        MsgBox(ExpandConstant('{cm:ErrorMandatoryField, {cm:Password}}'), mbError, MB_OK);
      end;
      Logger('error', 'Connection details validation failed: Password is empty');
      Result := False;
    end
    else
    begin
      Logger('info', 'Connection details validated: ' + ConnectionInputPage.Values[0] + ', ' + ConnectionInputPage.Values[1] + ', ' + ConnectionInputPage.Values[2]);
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    URL := ConnectionInputPage.Values[0];
    USERNAME := ConnectionInputPage.Values[1];
    PASSWORD := ConnectionInputPage.Values[2];
    CERTIFICATE := ConnectionInputPage.Values[3];
    INVENTORY_MODE := StrToInt64Def(ConfigInputPage.Values[0], 2);
    LOG_LEVEL := StrToInt64Def(ConfigInputPage.Values[1], 2);

    STORE_DATA_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent');
    CONFIG_PATH := STORE_DATA_PATH + '\config.json';
    LOG_PATH := STORE_DATA_PATH + '\ocsinventory-agent.log';

    if not DirExists(STORE_DATA_PATH) then
    begin
      Logger('info', 'Data directory does not exist, attempting to create: ' + STORE_DATA_PATH);

      if CreateDir(STORE_DATA_PATH) then
      begin
        Logger('info', 'Data directory created successfully: ' + STORE_DATA_PATH);
      end
      else
      begin
        if not Silent then
        begin
          MsgBox('Failed to create OCSInventory-Agent data directory. Please check the logs for more details.', mbError, MB_OK);
        end;
        Logger('error', 'Failed to create data directory: ' + STORE_DATA_PATH);
      end;
    end
    else
    begin
      Logger('info', 'Data directory found: ' + STORE_DATA_PATH);
    end;

    if SaveStringToFile(CONFIG_PATH, Format('{"url": "%s", "username": "%s", "password": "%s", "certificate": "%s", "bypass_certificate": false, "log_file": true, "log_level": %d, "mode": %d, "data_directory": "%s", "log_file_path": "%s"}', [URL, USERNAME, PASSWORD, CERTIFICATE, LOG_LEVEL, INVENTORY_MODE, STORE_DATA_PATH, LOG_PATH]), false) then
    begin
      Logger('info', 'Configuration file created successfully: ' + CONFIG_PATH);
    end
    else
    begin
      if not Silent then
      begin
        MsgBox('Failed to create configuration file. Please check the logs for more details.', mbError, MB_OK);
      end;
      Logger('error', 'Failed to create configuration file: ' + CONFIG_PATH);
    end;

    if InstallAsAServiceCheckBox.Checked then
    begin
      Logger('info', 'Installing OCSInventory Agent as a service...');

      if Exec('sc.exe', 'create "OCSInventory Agent" binpath= "' + ExpandConstant('{app}\{#AppExeName}') + '" start= "auto"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        Logger('info', 'Service created successfully');
        
        if Exec('sc.exe', 'description "OCSInventory Agent" "' + ExpandConstant('{cm:ServiceDescription}') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          Logger('info', 'Service description set successfully');
        end
        else
        begin
          if not Silent then
          begin
            MsgBox(ExpandConstant('{cm:ServiceCreateFailed}'), mbError, MB_OK);
          end;
          Logger('error', 'Failed to set service description for OCSInventory Agent');
        end;

        if not Exec('sc.exe', 'start "OCSInventory Agent"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          if not Silent then
          begin
            MsgBox(ExpandConstant('{cm:ServiceStartFailed}'), mbError, MB_OK);
          end;
          Logger('error', 'Failed to start OCSInventory Agent service');
        end;
      end
      else
      begin
        if not Silent then
        begin
          MsgBox(ExpandConstant('{cm:ServiceCreateFailed}'), mbError, MB_OK);
        end;
        Logger('error', 'Failed to create OCSInventory Agent service');
      end;
    end
    else if RunNowCheckBox.Checked then
    begin
      Logger('info', 'Running OCSInventory Agent immediately...');

      if Exec(ExpandConstant('{app}\{#AppExeName}'), '', '', SW_HIDE, ewNoWait, ResultCode) then
      begin
        Logger('info', 'OCSInventory Agent has been executed successfully');
      end
      else
      begin
        if not Silent then
        begin
          MsgBox('Failed to run OCSInventory Agent. Please check the logs for more details.', mbError, MB_OK);
        end;
        Logger('error', 'Failed to run OCSInventory Agent');
      end;
    end;
    Logger('info', 'OCSInventory Agent installation steps finished');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if Exec('sc.exe', 'stop "OCSInventory Agent"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if not Exec('sc.exe', 'delete "OCSInventory Agent"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        if not Silent then
        begin
          MsgBox(ExpandConstant('{cm:ServiceDeleteFailed}'), mbError, MB_OK);
        end;
      end;
    end
    else
    begin
      if not Silent then
      begin
        MsgBox(ExpandConstant('{cm:ServiceStopFailed}'), mbError, MB_OK);
      end;
    end;

    if DirExists(STORE_DATA_PATH) then
    begin
      if not RemoveDir(STORE_DATA_PATH) then
      begin
        if not Silent then
        begin
          MsgBox('Failed to remove OCSInventory-Agent data directory.', mbError, MB_OK);
        end;
      end;
    end;
  end;
end;

[CustomMessages]
AgentConfigurationPageTitle=Agent configuration
AgentConfigurationPageDescription=Please specify your own agent settings.
MandatoryFields=* Required fields are marked with an asterisk.
URL=URL
Username=Username
Password=Password
Certificate=Certificate
AgentMode=Agent mode
LogLevel=Log level
RunNow=Run the agent now
InstallAsAService=Install agent as a service
ErrorMandatoryField=Error: %1 is a mandatory field!
ServiceDescription=Service starting periodically OCSInventory Agent for Windows
ServiceCreateFailed=Failed to create the OCSInventory Agent service. Please check the logs for more details.
ServiceStartFailed=Failed to start the OCSInventory Agent service. Please check the logs for more details.
ServiceStopFailed=Failed to stop the OCSInventory Agent service. Please check the logs for more details.
ServiceDeleteFailed=Failed to delete the OCSInventory Agent service. Please check the logs for more details.

french.AgentConfigurationPageTitle=Configuration de l'agent
french.AgentConfigurationPageDescription=Veuillez spécifier vos propres paramètres d'agent.
french.MandatoryFields=* Les champs obligatoires sont marqués d'un astérisque.
french.URL=URL
french.Username=Nom d'utilisateur
french.Password=Mot de passe
french.Certificate=Certificat
french.AgentMode=Mode de l'agent
french.LogLevel=Niveau de journalisation
french.RunNow=Exécuter l'agent maintenant
french.InstallAsAService=Installer l'agent en tant que service
french.ErrorMandatoryField=Erreur: %1 est un champ obligatoire !
french.ServiceDescription=Service démarrant périodiquement l'agent OCSInventory pour Windows
french.ServiceCreateFailed=Échec de la création du service OCSInventory Agent. Veuillez vérifier les logs pur plus de détails.
french.ServiceStartFailed=Échec du démarrage du service OCSInventory Agent. Veuillez vérifier les logs pur plus de détails.
french.ServiceStopFailed=Échec de l'arrêt du service OCSInventory Agent. Veuillez vérifier les logs pur plus de détails.
french.ServiceDeleteFailed=Échec de la suppression du service OCSInventory Agent. Veuillez vérifier les logs pur plus de détails.
