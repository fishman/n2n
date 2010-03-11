//
//  AppController.m
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import "AppController.h"

#define PROTONET_GANESH @"com.protonet.ganesh"
#define N2N_CONNECT_EDGE @"N2NEdgeConnect"
#define N2N_DISCONNECT_EDGE @"N2NEdgeDisconnect"

@implementation AppController


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

/**
 * register connectiondiddie and terminatenotifications
 */
- (id) init
{
    if (self = [super init]){
        NSLog(@"n2n daemon initializing.");
        // initialize user defaults
        [self initDefaults];
        serverConnection = [NSConnection connectionWithRegisteredName:@"N2NServerConnection" host:nil];
        if(serverConnection == nil){
            NSLog(@"Could not connect to server with name N2NServerConnection");
            [NSApp terminate:self];
        }
        [serverConnection setDelegate:self];
        [serverConnection retain];

        n2nThread = [[[N2NThread alloc] init] retain];

        [[NSDistributedNotificationCenter defaultCenter] addObserver:n2nThread
                                                            selector:@selector(edgeConnect:)
                                                                name:N2N_CONNECT_EDGE
                                                              object:nil];

        [[NSDistributedNotificationCenter defaultCenter] addObserver:n2nThread
                                                            selector:@selector(edgeDisconnect:)
                                                                name:N2N_DISCONNECT_EDGE
                                                              object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionDidDie:)
                                                     name:NSConnectionDidDieNotification
                                                   object:serverConnection];

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
    [n2nThread release];
    [serverConnection release];
    
    [super dealloc];
}

@end
