//
//  ThreadController.m
//  n2n
//
//  Created by Reza Jelveh on 26.09.10.
//  Copyright 2010 Protonet.info. All rights reserved.
//

#import "ThreadController.h"
#import "N2NThread.h"
#import "debug.h"

@implementation ThreadController

- (id)init {
    if(self = [super init]) {
        _threads = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_threads release];
    [super dealloc];
}

- (void) edgeConnect:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSArray *networks     = [[NSUserDefaults standardUserDefaults] objectForKey:@"networks"];
    NSDictionary *network;
    NSThread *edgeThread;
    
    if([[notification object] isKindOfClass:[NSString class]] &&
       (network = [networks objectAtIndex:[[notification object] intValue]])!= nil){
        NSLog(@"create thread and try to connect");
        
        edgeThread = [[N2NThread alloc] initWithId:[notification object]
                                        andNetwork:[NSDictionary dictionaryWithDictionary:network]];
        
        [_threads setObject:edgeThread forKey:[notification object]];
        [edgeThread start];
    }
    else {
        [[NSDistributedNotificationCenter defaultCenter]
         postNotification:[NSNotification notificationWithName:N2N_DISCONNECTED object:[notification object]]];
    }
}

- (void) edgeDisconnect:(NSNotification *)notification
{
    [[_threads objectForKey:[notification object]] cancel];
    [_threads removeObjectForKey:[notification object]];
}

@end
