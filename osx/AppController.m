//
//  AppController.m
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import "AppController.h"

#define PROTONET_GANESH @"com.protonet.ganesh"

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
        NSLog(@"wassup");
        // initialize user defaults
        [self initDefaults];

        n2nThread = [[[N2NThread alloc] init] retain];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(connectionDidDie:)
                                                     name:NSConnectionDidDieNotification
                                                   object:nil];

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(workspaceDidTerminateApplication:)
                                                                   name:NSWorkspaceDidTerminateApplicationNotification
                                                                 object:nil];
        [[NSConnection defaultConnection] setRootObject:self];
        [[NSConnection defaultConnection] registerName:@"n2ndaemon"];
        [[NSRunLoop currentRunLoop] configureAsServer];
    }

    return self;
}

- (void) dealloc
{
    [n2nThread release];

    [super dealloc];
}

@end
