/*
 * (C) 2009    - Reza Jelveh <rjelveh@protonet.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>
 *
*/

#ifndef _EDGE_H_
#define _EDGE_H_

#include "minilzo.h"
#include "n2n.h"
#include <assert.h>
#include <sys/stat.h>

/** Time between logging system STATUS messages */
#define STATUS_UPDATE_INTERVAL (30 * 60) /*secs*/

/* maximum length of command line arguments */
#define MAX_CMDLINE_BUFFER_LENGTH    4096
/* maximum length of a line in the configuration file */
#define MAX_CONFFILE_LINE_LENGTH     1024

struct n2n_edge
{
  u_char              re_resolve_supernode_ip;
  struct peer_addr    supernode;
  char                supernode_ip[48];
  char *              community_name /*= NULL*/;
  
  /*     int                 sock; */
  /*     char                is_udp_socket /\*= 1*\/; */
  n2n_sock_info_t     sinfo;

  u_int               pkt_sent /*= 0*/;
  tuntap_dev          device;
  int                 allow_routing /*= 0*/;
  int                 drop_ipv6_ndp /*= 0*/;
  char *              encrypt_key /* = NULL*/;
  TWOFISH *           enc_tf;
  TWOFISH *           dec_tf;

  struct peer_info *  known_peers /* = NULL*/;
  struct peer_info *  pending_peers /* = NULL*/;
  time_t              last_register /* = 0*/;
};

#define N2N_NETMASK_STR_SIZE 16 /* dotted decimal 12 numbers + 3 dots */

#endif /* _EDGE_H_ */
