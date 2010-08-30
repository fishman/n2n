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
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <sys/sockio.h>
#include <limits.h>
#include <signal.h>

#define ADDRESS "/tmp/n2n"
#define N2N_OSX_TAPDEVICE_SIZE 32
#define TAP_IFNAME_LEN         7 /* tap255 - longest name */

#define QLEN 10

/* size of control buffer to send/recv one file descriptor */
#define CONTROLLEN  CMSG_LEN(sizeof(int))

static struct cmsghdr   *cmptr = NULL;  /* malloc'ed first time */

#define assumes(e)  \
        (__builtin_expect(!(e), 0) ? _log_tap_bug(__FILE__, __LINE__, #e), false : true)

void
_log_tap_bug(const char *path, unsigned int line, const char *test)
{
    int saved_errno = errno;
    const char *file = strrchr(path, '/');

    if (!file) {
        file = path;
    } else {
        file += 1;
    }

    fprintf(stderr, "Bug: %s:%u %u: %s\n", file, line, saved_errno, test);
}

/*
 * Pass a file descriptor to another process.
 * If fd<0, then -fd is sent back instead as the error status.
 */
int
send_fd(int fd, int fd_to_send)
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

int sock_server(int fd_to_send){
    int fd, cfd;
    struct sockaddr_un saun;

    if((fd = socket(PF_UNIX, SOCK_STREAM, 0)) < 0){
        perror("server: socket");
        return -1;
    }

    saun.sun_family = AF_UNIX;
    strcpy(saun.sun_path, ADDRESS);
    unlink(saun.sun_path);

    if (bind(fd, (struct sockaddr *)&saun, sizeof(saun)) < 0) {
        perror("server: bind");
        return -2;
    }
    chmod(saun.sun_path, 0777);

    if (listen(fd, QLEN) < 0) { /* tell kernel we're a server */
        perror("server: listen");
        return -3;
    }

    NSLog(@"Waiting for client connection");
    cfd = accept(fd, NULL, NULL);
    if (cfd < 0) {
        perror("server: accept");
        return -4;
    }

    if (send_fd(cfd, fd_to_send)) {
        perror("client: send fd");
        return -1;
    }
    NSLog(@"Sent file descriptor");

    return fd;
}

#define MAX_CMDLINE_BUFFER 256

int main (int argc, const char * argv[]) {
    int fd, i;
    char tap_device[N2N_OSX_TAPDEVICE_SIZE];
    char ip_address[MAX_CMDLINE_BUFFER];
    char buf[MAX_CMDLINE_BUFFER];
    char cmd_switch[3];
    char tap_num[4];
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    if(argc<3){
        NSLog(@"TunHelper parameters incorrect");
        return -1;
    }

    // some really simple input formatting checks
    strncpy(cmd_switch, argv[1], sizeof(cmd_switch));
    if(cmd_switch[0] == '-'){
        if(cmd_switch[1] == 's'){
            strncpy(ip_address, argv[2], sizeof(ip_address));
            NSLog(@"TunHelper started!, ip: %s, %d", ip_address, argc);
            for (i = 0; i < 255; i++) {
                snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);

                fd = open(tap_device, O_RDWR);
                if(fd > 0) {
                    NSLog(@"Succesfully opened %s, fd: %d", tap_device, fd);

                    snprintf(buf, sizeof(buf), "ifconfig tap%d %s netmask %s mtu %d up",
                             i, ip_address, "255.255.255.0", 1400);
                    system(buf);

                    // traceEvent(TRACE_NORMAL, "Interface tap%d up and running (%s/%s)",
                    //            i, device_ip, device_mask);

                    sock_server(fd);
                    break;
                }
            }
        }
       else if(cmd_switch[1] == 'd'){
           // 255 = maximum 4 characters 255\0
           strncpy(tap_num, argv[2], sizeof(tap_num));
           tap_num[3] = '\0';
           i = atoi(tap_num);
           if(i < 256){
               setuid(0);
               snprintf(buf, sizeof(buf), "ipconfig set tap%d DHCP", i);
               NSLog(@"Executing buf %s", buf);
               system(buf);
           }
       }
    }


    [pool drain];
    return i;
}
