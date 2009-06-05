//
//  AppController.m
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import "AppController.h"


@implementation AppController

- (id) init
{
    if (self = [super init]){
        NSLog(@"wassup");

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

@end
