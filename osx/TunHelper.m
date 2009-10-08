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

#define ADDRESS "/tmp/somesocketstuffs"
#define N2N_OSX_TAPDEVICE_SIZE 32

int send_fd(int sock, int fd)
{
    struct msghdr msghdr;
    char nothing = '!';
    struct iovec nothing_ptr;
    struct cmsghdr *cmsg;
    struct {
        struct cmsghdr h;
        int fd[1];
    } buffer;

    nothing_ptr.iov_base = &nothing;
    nothing_ptr.iov_len = 1;
    msghdr.msg_name = NULL;
    msghdr.msg_namelen = 0;
    msghdr.msg_iov = &nothing_ptr;
    msghdr.msg_iovlen = 1;
    msghdr.msg_flags = 0;
    msghdr.msg_control = (void*)&buffer;
    msghdr.msg_controllen = sizeof(struct cmsghdr) + sizeof(int);
    cmsg = CMSG_FIRSTHDR(&msghdr);
    cmsg->cmsg_len = msghdr.msg_controllen;
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    ((int *)CMSG_DATA(cmsg))[0] = fd;

    return(sendmsg(sock, &msghdr, 0) >= 0 ? 0 : -1);
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
