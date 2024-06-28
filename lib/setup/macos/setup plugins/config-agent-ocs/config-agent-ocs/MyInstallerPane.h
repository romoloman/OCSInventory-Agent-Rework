//
//  MyInstallerPane.h
//  config-agent-ocs
//
//  Created by Factorfx Factorfx on 18/06/2024.
//

#import <InstallerPlugins/InstallerPlugins.h>

@interface MyInstallerPane : InstallerPane{
    IBOutlet NSTextField *server;
    IBOutlet NSTextField *username;
    IBOutlet NSTextField *password;
    IBOutlet NSButton *serviceMode;
    IBOutlet NSPopUpButton *logLevelList;

    
    NSFileManager *filemgr;
}
    
@end
