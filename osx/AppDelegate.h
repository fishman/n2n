//
//  AppController.h
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ThreadController;

@interface AppDelegate : NSObject {
    ThreadController *threadController;
    NSProxy *serverProxy;
}

@end
