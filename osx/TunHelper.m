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

/* size of control buffer to send/recv one file descriptor */
#define CONTROLLEN  CMSG_LEN(sizeof(int))

static struct cmsghdr   *cmptr = NULL;  /* malloc'ed first time */

int send_fd(int fd, int fd_to_send)
{
    struct iovec    iov[1];
    struct msghdr   msg;
    char            buf[2]; /* send_fd()/recv_fd() 2-byte protocol */

    iov[0].iov_base = buf;
    iov[0].iov_len  = 2;
    msg.msg_iov     = iov;
    msg.msg_iovlen  = 1;
    msg.msg_name    = NULL;
    msg.msg_namelen = 0;
    if (fd_to_send < 0) {
        msg.msg_control    = NULL;
        msg.msg_controllen = 0;
        buf[1] = -fd_to_send;   /* nonzero status means error */
        if (buf[1] == 0)
            buf[1] = 1; /* -256, etc. would screw up protocol */
    } else {
        if (cmptr == NULL && (cmptr = malloc(CONTROLLEN)) == NULL)
            return(-1);
        cmptr->cmsg_level  = SOL_SOCKET;
        cmptr->cmsg_type   = SCM_RIGHTS;
        cmptr->cmsg_len    = CONTROLLEN;
        msg.msg_control    = cmptr;
        msg.msg_controllen = CONTROLLEN;
        *(int *)CMSG_DATA(cmptr) = fd_to_send;     /* the fd to pass */
        buf[1] = 0;          /* zero status means OK */
    }
    buf[0] = 0;              /* null byte flag to recv_fd() */
    if (sendmsg(fd, &msg, 0) != 2)
        return(-1);
    return(0);
}

int sock_client(int fd)
{
    int s,len;
    struct sockaddr_un saun;

    if((s = socket(PF_LOCAL, SOCK_STREAM, 0)) < 0){
        perror("client: socket");
    }

    saun.sun_family = PF_LOCAL;
    strcpy(saun.sun_path, ADDRESS);

    len = sizeof(saun.sun_family) + strlen(saun.sun_path);

    if (connect(s, (const struct sockaddr *)&saun, len) < 0) {
        perror("client: connect");
        exit(1);
    }

    if (send_fd(s, fd)) {
        perror("client: send fd");
        exit(1);
    }
    unlink(ADDRESS);

    return 0;
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
