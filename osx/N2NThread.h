//
//  N2NThread.h
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "edge.h"

@interface N2NThread : NSThread {
    NSString *_id;
    NSDictionary *_network;
}

@property(copy) NSString *_id;
@property(retain) NSDictionary *_network;

@end
