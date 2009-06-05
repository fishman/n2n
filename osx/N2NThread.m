//
//  N2NThread.m
//  n2n
//
//  Created by Reza Jelveh on 6/5/09.
//  Copyright 2009 Protonet.info. All rights reserved.
//

#import "N2NThread.h"

@implementation N2NThread

- (void) threadMethod:(id)theObject
{
    NSLog(@"thread started");

    ipAddress     = [[NSUserDefaults standardUserDefaults] stringForKey:@"ipAddress"];
    encryptKey    = [[NSUserDefaults standardUserDefaults] stringForKey:@"encryptKey"];
    communityName = [[NSUserDefaults standardUserDefaults] stringForKey:@"communityName"];
    supernodeIp   = [[NSUserDefaults standardUserDefaults] stringForKey:@"supernodeIp"];

    int local_port = 0 /* any port */;
    char *tuntap_dev_name = "edge0";
    char  netmask[N2N_NETMASK_STR_SIZE]="255.255.255.0";
    int   mtu = DEFAULT_MTU;

    size_t numPurged;
    time_t lastStatus=0;

    char * device_mac=NULL;

    int     i;
    char  * linebuffer = NULL;
    char *ip_addr        = [ipAddress cString];
    char *encrypt_key    = [encryptKey cString];
    char *community_name = [communityName cString];
    char *supernode_ip   = [supernodeIp cString];

    n2n_edge_t eee; /* single instance for this program */

    if (-1 == edge_init(&eee) ){
        traceEvent( TRACE_ERROR, "Failed in edge_init" );
        exit(1);
    }


    eee.community_name = strdup(community_name);
    if(strlen(eee.community_name) > COMMUNITY_LEN)
        eee.community_name[COMMUNITY_LEN] = '\0';

    snprintf(eee.supernode_ip, sizeof(eee.supernode_ip), "%s", supernode_ip);
    supernode2addr(&eee, eee.supernode_ip);

    memset(&(eee.supernode), 0, sizeof(eee.supernode));
    eee.supernode.family = AF_INET;

    if(tuntap_open(&(eee.device), tuntap_dev_name, ip_addr, netmask, device_mac, mtu) < 0)
        return(-1);

    if(local_port > 0)
        traceEvent(TRACE_NORMAL, "Binding to local port %d", local_port);

    if(edge_init_twofish( &eee, (u_int8_t *)(encrypt_key), strlen(encrypt_key) ) < 0) return(-1);
    eee.sinfo.sock = open_socket(local_port, eee.sinfo.is_udp_socket, 0);
    if(eee.sinfo.sock < 0) return(-1);

    if( !(eee.sinfo.is_udp_socket) ) {
        int rc = connect_socket(eee.sinfo.sock, &(eee.supernode));

        if(rc == -1) {
            traceEvent(TRACE_WARNING, "Error while connecting to supernode\n");
            return(-1);
        }
    }

    update_registrations(&eee);

    traceEvent(TRACE_NORMAL, "");
    traceEvent(TRACE_NORMAL, "Ready");

    /* Main loop
     *
     * select() is used to wait for input on either the TAP fd or the UDP/TCP
     * socket. When input is present the data is read and processed by either
     * readFromIPSocket() or readFromTAPSocket()
     */

    while(1) {
        int rc, max_sock = 0;
        fd_set socket_mask;
        struct timeval wait_time;
        time_t nowTime;

        FD_ZERO(&socket_mask);
        FD_SET(eee.sinfo.sock, &socket_mask);

        wait_time.tv_sec = SOCKET_TIMEOUT_INTERVAL_SECS; wait_time.tv_usec = 0;

        rc = select(max_sock+1, &socket_mask, NULL, NULL, &wait_time);
        nowTime=time(NULL);

        if(rc > 0)
        {
            /* Any or all of the FDs could have input; check them all. */

            if(FD_ISSET(eee.sinfo.sock, &socket_mask))
            {
                /* Read a cooked socket from the internet socket. Writes on the TAP
                 * socket. */
                readFromIPSocket(&eee);
            }

        }

        update_registrations(&eee);

        numPurged =  purge_expired_registrations( &(eee.known_peers) );
        numPurged += purge_expired_registrations( &(eee.pending_peers) );
        if ( numPurged > 0 )
        {
            traceEvent( TRACE_NORMAL, "Peer removed: pending=%ld, operational=%ld",
                        peer_list_size( eee.pending_peers ), peer_list_size( eee.known_peers ) );
        }

        if ( ( nowTime - lastStatus ) > STATUS_UPDATE_INTERVAL )
        {
            lastStatus = nowTime;

            traceEvent( TRACE_NORMAL, "STATUS: pending=%ld, operational=%ld",
                        peer_list_size( eee.pending_peers ), peer_list_size( eee.known_peers ) );
        }
    } /* while */
}

- (void) edgeConnect:(NSNotification *)notification
{
    NSLog(@"hello world");

    edgeThread = [[NSThread alloc] initWithTarget:self
                                         selector:@selector(threadMethod:)
                                           object:nil];
    [edgeThread start];
}

- (void) disconnect
{
    [edgeThread exit];
#if 0
    send_deregister( &eee, &(eee.supernode));

    closesocket(eee.sinfo.sock);
    tuntap_close(&(eee.device));

    edge_deinit( &eee );
#endif
}


@end
