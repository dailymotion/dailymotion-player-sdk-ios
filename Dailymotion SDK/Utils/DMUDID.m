//
//  DMUDID.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 12/06/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "DMUDID.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

// MAC address of the first interface as MD5
static NSString *deviceIdentifier;

@implementation DMUDID

+ (void)initialize
{
    int mib[6];
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;

    if ((mib[5] = if_nametoindex("en0")) == 0) return;

    char *buf;
    size_t len;
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) return;
    if ((buf = malloc(len)) == NULL) return;

    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0)
    {
        free(buf);
        return;
    }

    struct if_msghdr *ifm = (struct if_msghdr *)buf;
    struct sockaddr_dl *sdl = (struct sockaddr_dl *)(ifm + 1);
    unsigned char *str = (unsigned char *)LLADDR(sdl);

    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen((char *)str), r);
    deviceIdentifier = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                        r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];

    free(buf);
}

+ (NSString *)deviceIdentifier
{
    return deviceIdentifier;
}

@end
