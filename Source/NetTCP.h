/***************************************************************************
                                NetTCP.h
                          -------------------
    begin                : Fri Nov  2 01:19:16 UTC 2001
    copyright            : (C) 2005 by Andrew Ruder
    email                : aeruder@ksu.edu
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Lesser General Public License as        *
 *   published by the Free Software Foundation; either version 2.1 of the  *
 *   License or (at your option) any later version.                        *
 *                                                                         *
 ***************************************************************************/

@class TCPSystem, TCPConnecting, TCPPort, TCPTransport;

#ifndef NET_TCP_H
#define NET_TCP_H

#import "NetBase.h"
#import <Foundation/NSObject.h>

#include <netinet/in.h>
#include <stdint.h>

@class NSString, NSNumber, NSString, NSData, NSMutableData, TCPConnecting;
@class TCPTransport, TCPSystem, NSHost;

extern NSString *NetclassesErrorTimeout;
extern NSString *NetclassesErrorBadAddress;
extern NSString *NetclassesErrorAborted;
 
@interface TCPSystem : NSObject
	{
		NSString *errorString;
		int errorNumber;
	}
+ sharedInstance;

- (NSString *)errorString;
- (int)errorNumber;

- (id <NetObject>)connectNetObject: (id <NetObject>)netObject toHost: (NSHost *)aHost 
                onPort: (uint16_t)aPort withTimeout: (int)aTimeout;

- (TCPConnecting *)connectNetObjectInBackground: (id <NetObject>)netObject
    toHost: (NSHost *)aHost onPort: (uint16_t)aPort withTimeout: (int)aTimeout;

- (BOOL)hostOrderInteger: (uint32_t *)aNumber fromHost: (NSHost *)aHost;
- (BOOL)networkOrderInteger: (uint32_t *)aNumber fromHost: (NSHost *)aHost;

- (NSHost *)hostFromHostOrderInteger: (uint32_t)ip;
- (NSHost *)hostFromNetworkOrderInteger: (uint32_t)ip;
@end

/**
 * A class can implement this protocol, and when it is connected in the 
 * background using -connectNetObjectInBackground:toHost:onPort:withTimeout:
 * it will receive the messages in this protocol which notify the object of
 * certain events while being connected in the background.
 */
@protocol TCPConnecting
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
- connectingStarted: (TCPConnecting *)aConnection;
@end

@interface TCPConnecting : NSObject < NetObject >
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

@interface TCPPort : NSObject < NetPort >
    {
		int desc;
		Class netObjectClass;
		uint16_t port;
	}
- initOnPort: (uint16_t)aPort;
- initOnHost: (NSHost *)aHost onPort: (uint16_t)aPort;

- (uint16_t)port;
- setNetObject: (Class)aClass;
- (int)desc;
- (void)close;
- (void)connectionLost;
- newConnection;
@end

@interface TCPTransport : NSObject < NetTransport >
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
