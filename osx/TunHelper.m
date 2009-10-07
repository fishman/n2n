//
//  TunHelper.m
//  n2n
//
//  Created by Reza Jelveh on 10/6/09.
//  Copyright 2009 Flying Seagull. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <limits.h>

#include "ancillary.h"

#define ADDRESS "/tmp/somesocketstuffs"
#define N2N_OSX_TAPDEVICE_SIZE 32

int socket_client(int fd)
{
    int s,len;
    struct sockaddr_un saun;
    
    if((s = socket(PF_LOCAL, SOCK_STREAM, 0)) < 0){
        perror("client: socket");
    }
    
    saun.sun_family = PF_LOCAL;
    strcpy(saun.sun_path, ADDRESS);
    
    len = sizeof(saun.sun_family) + strlen(saun.sun_path);
    
    if (connect(s, &saun, len) < 0) {
        perror("client: connect");
        exit(1);
    }
    
    if (ancil_send_fd(s, fd)) {
        perror("client: send fd");
        exit(1);
    }
    unlink(ADDRESS);
}

int main (int argc, const char * argv[]) {
    int fd, i;
    char tap_device[_POSIX_PATH_MAX];
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    NSLog(@"TunHelper started!");
    
    for (i = 0; i < 255; i++) {
        snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);
        
        fd = open(tap_device, O_RDWR);
        if(fd > 0) {
            NSLog(@"Succesfully opened %s", tap_device);
            break;
        }
    }

    sock_client(fd);
    [pool drain];
    return 0;
}
