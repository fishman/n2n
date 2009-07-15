/*
 * (C) 2007-09 - Luca Deri <deri@ntop.org>
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
 * along with this program; if not see see <http://www.gnu.org/licenses/>
 */

#include <Security/Authorization.h>
#include <Security/AuthorizationDB.h>
#include <CoreFoundation/CoreFoundation.h>
#include "n2n.h"

const char kTapRightName[] = "com.protonet.CreateTap";
#ifdef _DARWIN_
AuthorizationRef gAuthorization;
OSStatus AcquireRight(const char *rightName)
    // This routine calls Authorization Services to acquire
    // the specified right.
{
    OSStatus                         err;
    static const AuthorizationFlags  kFlags =
                  kAuthorizationFlagInteractionAllowed
                | kAuthorizationFlagExtendRights;
    AuthorizationItem   kActionRight = { rightName, 0, 0, 0 };
    AuthorizationRights kRights      = { 1, &kActionRight };

    assert(gAuthorization != NULL);

    // Request the application-specific right.

    err = AuthorizationCopyRights(
        gAuthorization,         // authorization
        &kRights,               // rights
        NULL,                   // environment
        kFlags,                 // flags
        NULL                    // authorizedRights
    );

    return err;
}

OSStatus SetupRight(
    AuthorizationRef    authRef,
    const char *        rightName,
    CFStringRef         rightRule,
    CFStringRef         rightPrompt
)
    // Checks whether a right exists in the authorization database
    // and, if not, creates the right and sets up its initial value.
{
    OSStatus err;

    // Check whether our right is already defined.

    err = AuthorizationRightGet(rightName, NULL);
    if (err == noErr) {

        // A right already exists, either set up in advance by
        // the system administrator or because this is the second
        // time we've run.  Either way, there's nothing more for
        // us to do.

    } else if (err == errAuthorizationDenied) {

        // The right is not already defined.  Let's create a
        // right definition based on the rule specified by the
        // caller (in the rightRule parameter).  This might be
        // kAuthorizationRuleClassAllow (which allows anyone to
        // acquire the right) or
        // kAuthorizationRuleAuthenticateAsAdmin (which requires
        // the user to authenticate as an admin user)
        // or some other value from "AuthorizationDB.h".  The
        // system administrator can modify this right as they
        // see fit.

        err = AuthorizationRightSet(
            authRef,                // authRef
            rightName,              // rightName
            rightRule,              // rightDefinition
            rightPrompt,            // descriptionKey
            NULL,                   // bundle, NULL indicates main
            NULL                    // localeTableName,
        );                          // NULL indicates
                                    // "Localizable.strings"

        // The ability to add a right is, itself, governed by a non-NULLdescriptionKey
        // right. If we can't get that right, we'll get an error
        // from the above routine.  We don't want that error
        // stopping the application from launching, so we
        // swallow the error.

        if (err != noErr) {
            #if ! defined(NDEBUG)
                fprintf(
                    stderr,
                    "Could not create default right (%ld)\n",
                    err
                );
            #endif
            err = noErr;
        }
    }

    return err;
}

OSStatus SetupAuthorization(void)
    // Called as the application starts up.  Creates a connection
    // to Authorization Services and then makes sure that our
    // right (kActionRightName) is defined.
{
    OSStatus err;

    // Connect to Authorization Services.

    err = AuthorizationCreate(NULL, NULL, 0, &gAuthorization);

    // Set up our rights.

    if (err == noErr) {
        err = SetupRight(
            gAuthorization,
            kTapRightName,
            CFSTR(kAuthorizationRuleAuthenticateAsAdmin),
            CFSTR("YOU MUST BE AUTHORIZED TO DO XYZ")
        );
    }

    return err;
}

void tun_close(tuntap_dev *device);

/* ********************************** */

#define N2N_OSX_TAPDEVICE_SIZE 32
int tuntap_open(tuntap_dev *device /* ignored */, 
                char *dev, 
                char *device_ip, 
                char *device_mask,
                const char * device_mac,
		int mtu) {
  int i;
  char tap_device[N2N_OSX_TAPDEVICE_SIZE];
  SetupAuthorization();

AcquireRight(kTapRightName);
  for (i = 0; i < 255; i++) {
    snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);

    device->fd = open(tap_device, O_RDWR);
    if(device->fd > 0) {
      traceEvent(TRACE_NORMAL, "Succesfully open %s", tap_device);
      break;
    }
  }
  
  if(device->fd < 0) {
    traceEvent(TRACE_ERROR, "Unable to open tap device");
    return(-1);
  } else {
    char buf[256];
    FILE *fd;

    device->ip_addr = inet_addr(device_ip);

    if ( device_mac )
    {
        /* FIXME - This is not tested. Might be wrong syntax for OS X */

        /* Set the hw address before bringing the if up. */
        snprintf(buf, sizeof(buf), "ifconfig tap%d ether %s",
                 i, device_mac);
        system(buf);
    }

    snprintf(buf, sizeof(buf), "ifconfig tap%d %s netmask %s mtu %d up",
             i, device_ip, device_mask, mtu);
    system(buf);

    traceEvent(TRACE_NORMAL, "Interface tap%d up and running (%s/%s)",
               i, device_ip, device_mask);

  /* Read MAC address */

    snprintf(buf, sizeof(buf), "ifconfig tap%d |grep ether|cut -c 8-24", i);
    /* traceEvent(TRACE_INFO, "%s", buf); */

    fd = popen(buf, "r");
    if(fd < 0) {
      tun_close(device);
      return(-1);
    } else {
      int a, b, c, d, e, f;

      buf[0] = 0;
      fgets(buf, sizeof(buf), fd);
      pclose(fd);
      
      if(buf[0] == '\0') {
	traceEvent(TRACE_ERROR, "Unable to read tap%d interface MAC address");
	exit(0);
      }

      traceEvent(TRACE_NORMAL, "Interface tap%d [MTU %d] mac %s", i, mtu, buf);
      if(sscanf(buf, "%02x:%02x:%02x:%02x:%02x:%02x", &a, &b, &c, &d, &e, &f) == 6) {
	device->mac_addr[0] = a, device->mac_addr[1] = b;
	device->mac_addr[2] = c, device->mac_addr[3] = d;
	device->mac_addr[4] = e, device->mac_addr[5] = f;
      }
    }
  }


  /* read_mac(dev, device->mac_addr); */
  return(device->fd);
}

/* ********************************** */

int tuntap_read(struct tuntap_dev *tuntap, unsigned char *buf, int len) {
  return(read(tuntap->fd, buf, len));
}

/* ********************************** */

int tuntap_write(struct tuntap_dev *tuntap, unsigned char *buf, int len) {
  return(write(tuntap->fd, buf, len));
}

/* ********************************** */

void tuntap_close(struct tuntap_dev *tuntap) {
  close(tuntap->fd);
}

#endif
