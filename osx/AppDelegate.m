//
//  AppController.m
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import "AppDelegate.h"
#import "ThreadController.h"
#import "edge.h"

#define PROTONET_GANESH   @"com.protonet.ganesh"

@implementation AppDelegate


- (void) initDefaults
{
    NSString *path;
    NSDictionary *dict;
    path = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    dict = [NSDictionary dictionaryWithContentsOfFile:path];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
}

- (void)connectionDidDie:(id)anArgument
{
    [NSApp terminate:self];
}

/**
 * Only terminate if requested from the ganesh frontend
 */
- (void)workspaceDidTerminateApplication:(NSNotification *)notif
{
    id bundle;

    bundle = [[notif userInfo] objectForKey:@"NSApplicationBundleIdentifier"];
    if ([bundle isEqual:PROTONET_GANESH])
       [NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [threadController terminateThreads];
}


/**
 * register connectiondiddie and terminatenotifications
 */
- (id) init
{
    if (self = [super init]){
        NSLog(@"n2n daemon initializing.");
        // initialize user defaults
        [self initDefaults];
        serverProxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"N2NServerConnection" host:nil];
        if(serverProxy == nil){
            NSLog(@"Could not connect to server with name N2NServerConnection");
            [NSApp terminate:self];
        }
        [serverProxy retain];

        threadController = [[ThreadController alloc] init];

        [[NSDistributedNotificationCenter defaultCenter] addObserver:threadController
                                                            selector:@selector(edgeConnect:)
                                                                name:N2N_CONNECT
                                                              object:nil];

        [[NSDistributedNotificationCenter defaultCenter] addObserver:threadController
                                                            selector:@selector(edgeDisconnect:)
                                                                name:N2N_DISCONNECT
                                                              object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionDidDie:)
                                                     name:NSConnectionDidDieNotification
                                                   object:nil];

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(workspaceDidTerminateApplication:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        [[NSRunLoop currentRunLoop] configureAsServer];
    }

    return self;
}

- (void) dealloc
{
    [threadController release];
    [serverProxy release];
    
    [super dealloc];
}

@end
