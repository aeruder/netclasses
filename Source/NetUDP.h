/***************************************************************************
 * Netclasses - UDP Socket Class
 * Netclasses copyright (c) 2001 Andy Ruder
 *
 * UDP Socket Class copyright (c) 2004 Jeremy Tregunna <jtregunna@fuqn.ca>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so.
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

/* This module is heavily based off of NetTCP. It's still got a lot of its
   crud, and is a work in progress. */

@class UDPSystem, UDPConnecting, UDPPort, UDPTransport;

#ifndef NET_UDP_H
#define NET_UDP_H

#include <sys/types.h>
#include <netinet/in.h>

#import <Foundation/NSObject.h>
#import "NetBase.h"

@class NSString, NSNumber, NSString, NSData, NSMutableData, NSHost;

@interface UDPSystem : NSObject
{
	/* I'm not sure how useful these will be just yet */
	NSString *errorString;
	int errorNumber;
}

+ sharedInstance;

- (id <NetObject>)connectNetObject: (id <NetObject>)netObject
                            toHost: (NSHost *)aHost
                            onPort: (uint16_t)aPort
                       withTimeout: (int)aTimeout;
- (UDPConnecting *)connectNetObjectInBackground: (id <NetObject>)netObject
                                         toHost: (NSHost *)aHost
                                         onPort: (uint16_t)aPort
                                    withTimeout: (int)aTimeout;

- (BOOL)hostOrderInteger: (uint32_t *)aNumber fromHost: (NSHost *)aHost;
- (BOOL)networkOrderInteger: (uint32_t *)aNumber fromHost: (NSHost *)aHost;

- (NSHost *)hostFromHostOrderInteger: (uint32_t)ip;
- (NSHost *)hostFromNetworkOrderInteger: (uint32_t)ip;
@end

/**
 * A class can implement this protocol, and when it is connected in the
 * background using -connectNetObjectInBackground:toHost:onPort:withTimeout:
 * it will receive the message in this protocol which notify the object of
 * certain events while being connected in the background.
 */
@protocol UDPConnecting
/**
 * Tells the class implementing this protocol that the error in
 * <var>aError</var> has occurred and the connection will not
 * be established
 */
- connectingFailed: (NSString *)aError;
/**
 * Tells the class implementing this protocol that the connection
 * has begun and will be using the connection place holder
 * <var>aConnection</var>
 */
- connectingStarted: (UDPConnecting *)aConnection;
@end

@interface UDPConnecting : NSObject <NetObject>
{
	id transport;
	id netObject;
	NSTimer *timeout;
}

- (id <NetObject>)netObject;
- (void)abortConnection;

- (void)connectionLost;
- connectionEstablished: (id <NetTransport>)aTransport;
- dataReceived: (NSData *)data;
- (id <NetTransport>)transport;
@end

@interface UDPPort : NSObject <NetPort>
{
	int desc;
	Class netObjectClass;
	uint16_t port;
}

- initOnPort: (uint16_t)aPort;
- initOnHost: (NSHost *)aHost onPort: (uint16_t)aPort;

- (uint16_t)port;
- setNetObject: (Class)class;
- (int)desc;
- (void)close;
- (void)connectionLost;
- newConnection;
@end

@interface UDPTransport : NSObject <NetTransport>
{
	int desc;
	BOOL connected;
	NSMutableData *writeBuffer;
	NSHost *remoteHost;
	NSHost *localHost;
}

- initWithDesc: (int)aDesc withRemoteHost: (NSHost *)theAddress;
- (NSData *)readData: (int)maxDataSize;
- (BOOL)isDoneWriting;
- writeData: (NSData *)aData;
- (NSHost *)localHost;
- (NSHost *)remoteHost;
- (int)desc;
- (void)close;
@end

#endif
