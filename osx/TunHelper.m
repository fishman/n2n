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

#if 1
/* size of control buffer to send/recv one file descriptor */
#define CONTROLLEN  CMSG_LEN(sizeof(int))

static struct cmsghdr   *cmptr = NULL;  /* malloc'ed first time */

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
#else
#define ANCIL_FD_BUFFER(n) \
    struct { \
	struct cmsghdr h; \
	int fd[n]; \
    }

int
ancil_send_fds_with_buffer(int sock, const int *fds, unsigned n_fds, void *buffer)
{
    struct msghdr msghdr;
    char nothing = '!';
    struct iovec nothing_ptr;
    struct cmsghdr *cmsg;
    int i;

    nothing_ptr.iov_base = &nothing;
    nothing_ptr.iov_len = 1;
    msghdr.msg_name = NULL;
    msghdr.msg_namelen = 0;
    msghdr.msg_iov = &nothing_ptr;
    msghdr.msg_iovlen = 1;
    msghdr.msg_flags = 0;
    msghdr.msg_control = buffer;
    msghdr.msg_controllen = sizeof(struct cmsghdr) + sizeof(int) * n_fds;
    cmsg = CMSG_FIRSTHDR(&msghdr);
    cmsg->cmsg_len = msghdr.msg_controllen;
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    for(i = 0; i < n_fds; i++)
	((int *)CMSG_DATA(cmsg))[i] = fds[i];
    return(sendmsg(sock, &msghdr, 0) >= 0 ? 0 : -1);
}

int
send_fd(int sock, int fd)
{
    ANCIL_FD_BUFFER(1) buffer;

    return(ancil_send_fds_with_buffer(sock, &fd, 1, &buffer));
}
#endif
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

int up_interface(char *tap_name, int sfd){
    struct ifreq ifreq;

    strncpy(ifreq.ifr_name, tap_name, IFNAMSIZ);

    if ( ioctl(sfd, SIOCGIFFLAGS, &ifreq) < 0 ) {
        perror("ioctl SIOCGIFFLAGS");
        return -1;
    }

    if ( !(ifreq.ifr_flags & IFF_UP) ) {
        printf("interface %s is down, bring it up\n", tap_name);

        ifreq.ifr_flags |= IFF_UP;

        if ( ioctl(sfd, SIOCSIFFLAGS, &ifreq) ) {
            perror("ioctl SIOCSIFFLAGS");
            return -1;
        }
    }

    return 0;
}

int set_ip(int tap_device, const char* ip, const char* netmask, int mtu){
    int sfd;
    int i;
    struct ifreq ifr;
    struct in_addr ip_addr;
    struct sockaddr_in *sin = (struct sockaddr_in *) &ifr.ifr_addr;

    char tap_name[TAP_IFNAME_LEN];

    if ((sfd = socket(AF_INET, SOCK_STREAM, 0))<0) {
        perror("socket()");
        return -1;
    }

    snprintf(tap_name, sizeof(tap_name), "tap%d", tap_device);
    strncpy(ifr.ifr_name, tap_name, IFNAMSIZ);

    /* netmask needs to be set before ip address */
    inet_aton(netmask, &ip_addr);
    sin->sin_addr = ip_addr;
    sin->sin_family = AF_INET;

    if ((i = ioctl(sfd, SIOCSIFNETMASK, &ifr))<0) {
        perror("ioctl()");
        return -1;
    }

    inet_aton(ip, &ip_addr);
    sin->sin_addr = ip_addr;

    if ((i = ioctl(sfd, SIOCSIFADDR, &ifr))<0) {
        perror("ioctl()");
        return -1;
    }

    ifr.ifr_mtu = mtu;
    if ((i = ioctl(sfd, SIOCSIFMTU, &ifr))<0) {
        perror("ioctl()");
        return -1;
    }


    up_interface(tap_name, sfd);

    NSLog(@"hello world: %s", ifr.ifr_name);
}

int main (int argc, const char * argv[]) {
    int fd, i;
    char tap_device[N2N_OSX_TAPDEVICE_SIZE];
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSLog(@"TunHelper started!");
    for (i = 0; i < 255; i++) {
        snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);

        fd = open(tap_device, O_RDWR);
        if(fd > 0) {
            NSLog(@"Succesfully opened %s, fd: %d", tap_device, fd);

            set_ip(i, "10.0.0.10", "255.255.255.0", 1400);
            sock_server(fd);
            break;
        }
    }

    [pool drain];
    return i;
}
