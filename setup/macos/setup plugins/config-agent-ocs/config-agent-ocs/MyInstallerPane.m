//
//  MyInstallerPane.m
//  config-agent-ocs
//
//  Created by Factorfx Factorfx on 18/06/2024.
//

#import "MyInstallerPane.h"

@implementation MyInstallerPane

- (NSString *)title
{
    return [[NSBundle bundleForClass:[self class]] localizedStringForKey:@"PaneTitle" value:nil table:nil];
}

- (NSArray *) logLevels {
    return [NSArray arrayWithObjects:@"Error", @"Warning", @"Info", @"Verbose", nil];
}

- (void)didEnterPane:(InstallerSectionDirection)dir {
    NSAlert *cfgFileExistsWrn;
    filemgr = [ NSFileManager defaultManager];
    
    if ([filemgr fileExistsAtPath:@"/etc/ocsinventory-agent/inventory.json"]) {
        //We display a warning dialog
        cfgFileExistsWrn = [[NSAlert alloc] init];
        
        [cfgFileExistsWrn setMessageText:NSLocalizedStringFromTableInBundle(@"Already_conf_warn",nil,[NSBundle bundleForClass:[self class]], @"Warning about already existing cofiguration file")];
        [cfgFileExistsWrn setInformativeText:NSLocalizedStringFromTableInBundle(@"Already_conf_warn_comment",nil,[NSBundle bundleForClass:[self class]], @"Warning about already existing configuration file comment")];
        [cfgFileExistsWrn addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Yes",nil,[NSBundle bundleForClass:[self class]], @"Yes button")];
        [cfgFileExistsWrn addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"No",nil,[NSBundle bundleForClass:[self class]], @"No button")];
        [cfgFileExistsWrn setAlertStyle:NSAlertStyleInformational];
        
        
        if ([cfgFileExistsWrn runModal] != NSAlertFirstButtonReturn) {
            // No button was clicked, we don't display config pane
            [self gotoNextPane];
        }
    }
    
    // Optional: Pre-fill fields or perform setup logic when the pane is shown
    self->server.stringValue = @"https://example.com:port";
    self->username.stringValue = @"";
    self->password.stringValue = @"";
    self->serviceMode.state = NSControlStateValueOff;
    self->runNow.state = NSControlStateValueOff;
    
    //Defaults for loglevel droping list
    [logLevelList removeAllItems];
    [logLevelList addItemWithTitle: @"Error"];
    [logLevelList addItemWithTitle: @"Warning"];
    [logLevelList addItemWithTitle: @"Info"];
    [logLevelList addItemWithTitle: @"Verbose"];
    [logLevelList selectItemWithTitle: @"Info"];
}

- (IBAction)chooseCacertFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    NSArray* fileTypes = [[NSArray alloc] initWithObjects:@"pem",@"PEM",@"crt",@"CRT",nil];
    
    //Configuration for the browse panel
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:fileTypes];
    
    // Get panel return value
    NSInteger clicked = [panel runModal];
    
    // If OK clicked only
    if (clicked == NSModalResponseOK) {
        for (NSURL *url in [panel URLs]) {
            // do something with the url here.
            NSString *path = url.path;
            [cacertfile setStringValue:path];
        }
    }
}

- (IBAction) chooseLogLevel:(id)sender {
    NSString *logLevel = [logLevelList titleOfSelectedItem];
    
    //We show the selected log level
    [logLevelList setTitle:logLevel];
}

- (BOOL)shouldExitPane:(InstallerSectionDirection)direction {
    NSAlert *caCertWrn;

    // Validate and process user input before exiting the pane
    if (direction == InstallerDirectionForward) {
        if (self->server.stringValue.length == 0 || self->username.stringValue.length == 0 || self->password.stringValue.length == 0) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Incomplete Information"];
            [alert setInformativeText:@"Please fill in all fields."];
            [alert addButtonWithTitle:@"OK"];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert runModal];
            return NO; // Prevent advancing if fields are incomplete
        }
        
        // Save configuration or perform actions with the entered data
        NSString *server = self->server.stringValue;
        NSString *username = self->username.stringValue;
        NSString *password = self->password.stringValue;
        BOOL serviceModeEnabled = (self->serviceMode.state == NSControlStateValueOn);
        BOOL runNowEnabled = (self->runNow.state == NSControlStateValueOn);
        NSString *logLevel = [logLevelList titleOfSelectedItem];
        NSString *cacert = self->cacertfile.stringValue;
        
        if ( [[cacertfile stringValue] length] == 0 ) {
            //We display a warning dialog
            caCertWrn = [[NSAlert alloc] init];
            
            [caCertWrn addButtonWithTitle:@"OK"];
            [caCertWrn setMessageText:NSLocalizedStringFromTableInBundle(@"Missing_cert_warn",nil,[NSBundle bundleForClass:[self class]], @"Warning about missing certificate file")];
            [caCertWrn setInformativeText:NSLocalizedStringFromTableInBundle(@"Missing_cert_warn_comment",nil,[NSBundle bundleForClass:[self class]], @"Warning about missing certificate file comment")];
            [caCertWrn setAlertStyle:NSAlertStyleInformational];
            [caCertWrn runModal];  // display the warning dialog
            
        }
        
        // Example: Save to a temporary file or perform further processing
        NSLog(@"Server: %@, Username: %@, Password: %@, LogLevel: %@, Service Mode: %@, Run now: %@, Certificat: %@", server, username, password, logLevel, serviceModeEnabled ? @"Yes" : @"No", runNowEnabled ? @"Yes" : @"No", cacert);
        
        // Example: Save to a temporary file or perform further processing
        NSString *configContent = [NSString stringWithFormat:@"server=%@\nusername=%@\npassword=%@\nlogLevel=%@\nserviceMode=%@\nrunNow=%@\ncertificat=%@\n", server, username, password, logLevel, serviceModeEnabled ? @"yes" : @"no", runNowEnabled ? @"yes" : @"no", cacert];
        NSString *tmpConfigFilePath = @"/tmp/installer_config.txt";
        [configContent writeToFile:tmpConfigFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            
    }
    
    return YES; // Allow advancing to the next pane or completing installation
}

@end
