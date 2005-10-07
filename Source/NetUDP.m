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

/**
 * <title>NetUDP reference</title>
 * <author name="Andrew Ruder">
 * 	<email address="aeruder@ksu.edu" />
 * 	<url url="http://www.aeruder.net" />
 * </author>
 * <version>Revision 1</version>
 * <date>November 8, 2003</date>
 * <copy>Andrew Ruder</copy>
 */

#import "NetUDP.h"
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSException.h>
#import <Foundation/NSHost.h>

#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netdb.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/time.h>

#ifndef GNUSTEP 
#ifndef socklen_t
typedef int socklen_t;
#endif
#endif

extern NSString *NetclassesErrorTimeout;
extern NSString *NetclassesErrorBadAddress;
extern NSString *NetclassesErrorAborted;

static UDPSystem *default_system = nil;

@interface UDPSystem (InternalUDPSystem)
- (int)openPort: (uint16_t)portNumber;
- (int)openPort: (uint16_t)portNumber onHost: (NSHost *)aHost;

- (int)connectToHost: (NSHost *)aHost onPort: (uint16_t)portNumber
         withTimeout: (int)timeout inBackground: (BOOL)background;

- setErrorString: (NSString *)anError withErrno: (int)aErrno;
@end

@interface UDPConnecting (InternalUDPConnecting)
- initWithNetObject: (id <NetObject>)netObject withTimeout: (int)aTimeout;
- connectingFailed: (NSString *)error;
- connectingSucceeded;
- timeoutReceived: (NSTimer *)aTimer;
@end
	
@interface UDPConnectingTransport : NSObject < NetTransport >
	{
		BOOL connected;
		int desc;
		NSHost *remoteHost;
		NSHost *localHost;
		NSMutableData *writeBuffer;
		UDPConnecting *owner;	
	}
- (NSMutableData *)writeBuffer;

- initWithDesc: (int)aDesc withRemoteHost: (NSHost *)theAddress
     withOwner: (UDPConnecting *)anObject;
	 
- (void)close;

- (NSData *)readData: (int)maxDataSize;
- (BOOL)isDoneWriting;
- writeData: (NSData *)data;

- (NSHost *)remoteHost;
- (NSHost *)localHost;
- (int)desc;
@end

@implementation UDPConnectingTransport
- (NSMutableData *)writeBuffer
{
	return writeBuffer;
}
- initWithDesc: (int)aDesc withRemoteHost: (NSHost *)theAddress 
     withOwner: (UDPConnecting *)anObject
{
	struct sockaddr_in x;
	socklen_t address_length = sizeof(x);
	
	if (!(self = [super init])) return nil;
	
	desc = aDesc;

	writeBuffer = [NSMutableData new];
	remoteHost = RETAIN(theAddress);
		
	owner = anObject;
	connected = YES;
	
	if (getsockname(desc, (struct sockaddr *)&x, &address_length) != 0) 
	{
		[[UDPSystem sharedInstance]
		  setErrorString: [NSString stringWithFormat:
		       @"initWithDesc:withRemoteHost:withOwner:: %s",
		  strerror(errno)] withErrno: errno];
		[self release];
		return nil;
	}
	
	localHost = RETAIN([[UDPSystem sharedInstance] 
	  hostFromNetworkOrderInteger: x.sin_addr.s_addr]);
	
	[[NetApplication sharedInstance] transportNeedsToWrite: self];

	return self;
}
- (void)dealloc
{
	[self close];
	
	RELEASE(writeBuffer);
	RELEASE(remoteHost);
	RELEASE(localHost);

	[super dealloc];
}
- (NSData *)readData: (int)maxDataSize
{
	return nil;
}
- (BOOL)isDoneWriting
{
	return YES;
}
- writeData: (NSData *)data
{
	char buffer[1];
	if (data)
	{
		NSLog(@"gotData: %s", [data bytes]);
		[writeBuffer appendData: data];
		return self;
	}
	
	if (recv(desc, buffer, sizeof(buffer), MSG_PEEK) == -1)
	{
		NSLog(@"gotData: %s", [data bytes]);
		if (errno != EAGAIN)
		{
			[owner connectingFailed: [NSString stringWithFormat:
			  @"-writeData: %s", 
			  strerror(errno)]];
			return self;
		}
	}
	
	[owner connectingSucceeded];
	return self;
}
- (NSHost *)remoteHost
{
	return remoteHost;
}
- (NSHost *)localHost
{
	return localHost;
}
- (int)desc
{
	return desc;
}
- (void)close
{
	if (connected)
	{
		close(desc);
		connected = NO;
	}
}
@end

@implementation UDPConnecting (InternalUDPConnecting)
- initWithNetObject: (id <NetObject>)aNetObject withTimeout: (int)aTimeout
{
	if (!(self = [super init])) return nil;
	
	netObject = RETAIN(aNetObject);
	if (aTimeout > 0)
	{
		timeout = RETAIN([NSTimer scheduledTimerWithTimeInterval:
		    (NSTimeInterval)aTimeout
		  target: self selector: @selector(timeoutReceived:)
		  userInfo: nil repeats: NO]);
	}
		
	return self;
}
- connectingFailed: (NSString *)error
{
	if ([netObject conformsToProtocol: @protocol(UDPConnecting)])
	{
		[netObject connectingFailed: error];
	}
	[timeout invalidate];
	[transport close];
	[[NetApplication sharedInstance] disconnectObject: self];

	return self;
}
- connectingSucceeded
{
	id newTrans = AUTORELEASE([[UDPTransport alloc] initWithDesc:
	    dup([transport desc])
	  withRemoteHost: [transport remoteHost]]);
	id buffer = RETAIN([transport writeBuffer]);
	
	[timeout invalidate];
	
	[[NetApplication sharedInstance] disconnectObject: self];
	[netObject connectionEstablished: newTrans];

	[newTrans writeData: buffer];
	RELEASE(buffer);

	return self;
}
- timeoutReceived: (NSTimer *)aTimer
{	
	if (aTimer != timeout)
	{
		[aTimer invalidate];
	}
	[self connectingFailed: NetclassesErrorTimeout];
	
	return self;
}
@end

/**
 * If an object was attempted to have been connected in the background, this 
 * is a placeholder for that ongoing connection.  
 * -connectNetObjectInBackground:toHost:onPort:withTimeout: will return an 
 * instance of this object.  This placeholder object can be used to cancel
 * an ongoing connection with the -abortConnection method.
 */
@implementation UDPConnecting
- (void)dealloc
{
	RELEASE(netObject);
	RELEASE(timeout);
	
	[super dealloc];
}
/**
 * Returns the object that will be connected by this placeholder object.
 */
- (id <NetObject>)netObject
{
	return netObject;
}
/**
 * Aborts the ongoing connection.  If the net object conforms to the 
 * [(UDPConnecting)] protocol, it will receive a 
 * [(UDPConnecting)-connectingFailed:] message with a argument of
 * <code>NetclassesErrorAborted</code>
 */
- (void)abortConnection
{
	[self connectingFailed: NetclassesErrorAborted];
}
/**
 * Cleans up the connection placeholder.
 */
- (void)connectionLost
{
	DESTROY(transport);
}
/**
 * Sets up the connection placeolder.  If the net object conforms to 
 * [(UDPConnecting)], it will receive a 
 * [(UDPConnecting)-connectingStarted:] with the instance of UDPConnecting
 * as an argument.
 */
- connectionEstablished: (id <NetTransport>)aTransport
{
	transport = RETAIN(aTransport);	
	[[NetApplication sharedInstance] connectObject: self];
	if ([netObject conformsToProtocol: @protocol(UDPConnecting)])
	{
		[netObject connectingStarted: self];
	}
	return self;
}
/**
 * This shouldn't happen while a class is connecting, but included to 
 * conform to the [(NetObject)] protocol.
 */
- dataReceived: (NSData *)data
{
	return self;
}
/**
 * Returns the transport used by this object.  Will not be the same transport
 * given to the net object when the connection is made.
 */
- (id <NetTransport>)transport
{
	return transport;
}
@end

@implementation UDPSystem (InternalUDPSystem)
- (int)openPort: (uint16_t)portNumber
{
	return [self openPort: portNumber onHost: nil];
}
- (int)openPort: (uint16_t)portNumber onHost: (NSHost *)aHost
{
	struct sockaddr_in sin;
	int temp;
	int myDesc;
	
	memset(&sin, 0, sizeof(struct sockaddr_in));
	
	if (!aHost) {
		sin.sin_addr.s_addr = htonl(INADDR_ANY);
	} else {
		if (inet_aton([[aHost address] cString], 
		    (struct in_addr *)(&(sin.sin_addr))) == 0) {
			[self setErrorString: NetclassesErrorBadAddress withErrno: 0];
			return -1;
		}	      
	}
	
	sin.sin_port = htons(portNumber);
	sin.sin_family = AF_INET;
	
	if ((myDesc = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
		[self setErrorString: [NSString stringWithFormat:
 		  @"-openPort:onHost: (socket()): %s", 
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	temp = 1;
	if (setsockopt(myDesc, SOL_SOCKET, SO_REUSEADDR, 
	               &temp, sizeof(temp)) == -1)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat:
		  @"-openPort:onHost: (setsockopt): %s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	if (bind(myDesc, (struct sockaddr *) &sin, sizeof(struct sockaddr)) < 0)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat:
		  @"-openPort:onHost: (bind()): %s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	temp = 1;
	if (setsockopt(myDesc, SOL_SOCKET, SO_KEEPALIVE, 
	               &temp, sizeof(temp)) == -1)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat:
		  @"-openPort:onHost: (setsockopt(2)): %s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
/*
	if (listen(myDesc, 5) == -1)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat:
		  @"-openPort:onHost: (listen()): %s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
*/

	return myDesc;
}
- (int)connectToHost: (NSHost *)host onPort: (uint16_t)portNumber 
       withTimeout: (int)timeout inBackground: (BOOL)bck
{
	int myDesc;
	struct sockaddr_in destAddr, srcAddr;
	int srcLen;
	char buffer[1];

	if (!host)
	{
		[self setErrorString: NetclassesErrorBadAddress withErrno: 0];
		return -1;
	}
	
	if ((myDesc = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
	{
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}

	destAddr.sin_family = AF_INET;
	destAddr.sin_port = htons(portNumber);
	if (!(inet_aton([[host address] cString], 
	    (struct in_addr *)(&destAddr.sin_addr))))
	{
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		close(myDesc);
		return -1;
	}
	memset(&(destAddr.sin_zero), 0, sizeof(destAddr.sin_zero));

	if (timeout > 0 || bck)
	{
		if (fcntl(myDesc, F_SETFL, O_NONBLOCK) == -1)
		{
			[self setErrorString: [NSString stringWithFormat: @"%s",
			  strerror(errno)] withErrno: errno];
			close(myDesc);
			return -1;
		}
	}

	srcAddr.sin_family = AF_INET;
	srcAddr.sin_addr.s_addr = htonl(INADDR_ANY);
	srcAddr.sin_port = htons(0);
	if (bind(myDesc, (struct sockaddr *)&srcAddr, sizeof(srcAddr)) < 0) {
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		close(myDesc);
		return -1;
	}

	srcLen = sizeof(srcAddr);
	if (recvfrom(myDesc, buffer, sizeof(buffer), MSG_PEEK,
	    (struct sockaddr *)&srcAddr, &srcLen) < 0) {
		// Not fatal
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
	}

	return myDesc;
}
- setErrorString: (NSString *)anError withErrno: (int)aErrno
{
	errorNumber = aErrno;
	
	if (anError == errorString) return self;

	RELEASE(errorString);
	errorString = RETAIN(anError);

	return self;
}
@end		
	
/** 
 * Used for certain operations in the TCP/IP system.  There is only one
 * instance of this class at a time, used +sharedInstance to get this
 * instance.
 */
@implementation UDPSystem
/**
 * Returns the one instance of UDPSystem currently in existence.
 */
+ sharedInstance
{
	return (default_system) ? default_system : [[self alloc] init];
}
- init
{
	if (!(self = [super init])) return nil;
	
	if (default_system)
	{
		[self release];
		return nil;
	}
	default_system = RETAIN(self);
	
	return self;
}
/** 
 * Returns the error string of the last error that occurred.
 */
- (NSString *)errorString
{
	return errorString;
}
/**
 * Returns the errno of the last error that occurred.  If it is some other
 * non-system error, this will be zero, but the error string shall be set
 * accordingly.
 */
- (int)errorNumber
{
	return errorNumber;
}
/** 
 * Will connect the object <var>netObject</var> to host <var>aHost</var>
 * on port <var>aPort</var>.  If this connection doesn't happen in 
 * <var>aTimeout</var> seconds or some other error occurs, it will return
 * nil and the error string and error number shall be set accordingly.
 * Otherwise this will return <var>netObject</var>
 */
- (id <NetObject>)connectNetObject: (id <NetObject>)netObject toHost: (NSHost *)aHost
                onPort: (uint16_t)aPort withTimeout: (int)aTimeout
{
	int desc;
	id transport;

	aHost = [NSHost hostWithAddress: [aHost address]];
	
	desc = [self connectToHost: aHost onPort: aPort withTimeout: aTimeout 
	  inBackground: NO];
	if (desc < 0)
	{
		return nil;
	}
	transport = AUTORELEASE([[UDPTransport alloc] initWithDesc: desc 
	 withRemoteHost: aHost]);
	
	if (!(transport))
	{
		close(desc);
		return nil;
	}

	[netObject connectionEstablished: transport];
	
	return netObject;
}
/**
 * Connects <var>netObject</var> to host <var>aHost</var> on the port 
 * <var>aPort</var>.  Returns a place holder object that finishes the
 * connection in the background.  The placeholder will fail if the connection
 * does not occur in <var>aTimeout</var> seconds.  Returns nil if an error 
 * occurs and sets the error string and error number accordingly.
 */
- (UDPConnecting *)connectNetObjectInBackground: (id <NetObject>)netObject 
    toHost: (NSHost *)aHost onPort: (uint16_t)aPort withTimeout: (int)aTimeout
{
	int desc;
	id transport;
	id object;

	aHost = [NSHost hostWithAddress: [aHost address]];

	desc = [self connectToHost: aHost onPort: aPort
	  withTimeout: 0 inBackground: YES];
	  
	if (desc < 0)
	{
		return nil;
	}
	
	object = AUTORELEASE([[UDPConnecting alloc] initWithNetObject: netObject
	   withTimeout: aTimeout]);
	transport = AUTORELEASE([[UDPConnectingTransport alloc] initWithDesc: desc 
	  withRemoteHost: aHost withOwner: object]);
	
	if (!transport)
	{
		close(desc);
		return nil;
	}
	
	[object connectionEstablished: transport];
	
	return object;
}
/**
 * Returns a host order 32-bit integer from a host
 * Returns YES on success and NO on failure, the result is stored in the
 * 32-bit integer pointed to by <var>aNumber</var>
 */
- (BOOL)hostOrderInteger: (uint32_t *)aNumber fromHost: (NSHost *)aHost
{
	struct in_addr addr;

	if (!aHost) return NO;
	if (![aHost address]) return NO;

	if (inet_aton([[aHost address] cString], &addr) != 0)
	{
		if (aNumber)
		{
			*aNumber = ntohl(addr.s_addr);
			return YES;
		}
	}

	return NO;
}
/**
 * Returns a network order 32-bit integer from a host
 * Returns YES on success and NO on failure, the result is stored in the
 * 32-bit integer pointed to by <var>aNumber</var>
 */
- (BOOL)networkOrderInteger: (uint32_t *)aNumber fromHost: (NSHost *)aHost
{
	struct in_addr addr;

	if (!aHost) return NO;
	if (![aHost address]) return NO;
	
	if (inet_aton([[aHost address] cString], &addr) != 0)
	{
		if (aNumber)
		{
			*aNumber = addr.s_addr;
			return YES;
		}
	}
	
	return NO;
}
/**
 * Returns a host from a network order 32-bit integer ip address.
 */
- (NSHost *)hostFromNetworkOrderInteger: (uint32_t)ip
{
	struct in_addr addr;
	char *temp;
	
	addr.s_addr = ip;

	temp = inet_ntoa(addr);
	if (temp)
	{
		return [NSHost hostWithAddress: [NSString stringWithCString: temp]];
	}

	return nil;
}
/**
 * Returns a host from a host order 32-bit integer ip address.
 */
- (NSHost *)hostFromHostOrderInteger: (uint32_t)ip
{
	struct in_addr addr;
	char *temp;
	
	addr.s_addr = htonl(ip);

	temp = inet_ntoa(addr);
	if (temp)
	{
		return [NSHost hostWithAddress: [NSString stringWithCString: temp]];
	}

	return nil;
}	
@end

/**
 * UDPPort is a class that is used to bind a descriptor to a certain
 * TCP/IP port and listen for connections.  When a connection is received,
 * it will create a class set with -setNetObject: and set it up with the new
 * connection.
 */
@implementation UDPPort
/** 
 * Initializes a port on <var>aHost</var> and binds it to port <var>aPort</var>.
 * If <var>aHost</var> is nil, it will set it up on all addresses on the local
 * machine.  Using zero for <var>aPort</var> will use a random currently 
 * available port number.  Use -port to find out where it is actually
 * bound to.
 */
- initOnHost: (NSHost *)aHost onPort: (uint16_t)aPort
{
	struct sockaddr_in x;
	socklen_t address_length = sizeof(x);
	
	if (!(self = [super init])) return nil;
	
	desc = [[UDPSystem sharedInstance] openPort: aPort onHost: aHost];

	if (desc < 0)
	{
		[self release];
		return nil;
	}
	if (getsockname(desc, (struct sockaddr *)&x, &address_length) != 0)
	{
		[[UDPSystem sharedInstance] setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		close(desc);
		[self release];
		return nil;
	}
	
	port = ntohs(x.sin_port);

	[[NetApplication sharedInstance] connectObject: self];
	return self;
}
/**
 * Calls -initOnHost:onPort: with a nil argument for the host.
 */
- initOnPort: (uint16_t)aPort
{
	return [self initOnHost: nil onPort: aPort];
}
/**
 * Sets the class that will be initialized if a connection occurs on this
 * port.  If <var>aClass</var> does not implement the [(NetObject)]
 * protocol, will throw a FatalNetException.
 */
- setNetObject: (Class)aClass
{
	if (![aClass conformsToProtocol: @protocol(NetObject)])
	{
		[NSException raise: FatalNetException
		  format: @"%@ does not conform to < NetObject >",
		    NSStringFromClass(aClass)];
	}
	
	netObjectClass = aClass;
	return self;
}
/**
 * Returns the low-level file descriptor for the port.
 */
- (int)desc
{
	return desc;
}
/**
 * Closes the descriptor.
 */
- (void)close
{
	close(desc);
}
/**
 * Called when the connection is closed.  This will call -close
 */
- (void)connectionLost
{
	[self close];
}
/**
 * Called when a new connection occurs.  Will initialize a new object
 * of the class set with -setNetObject: with the new connection.
 */
- newConnection
{
	int newDesc;
	struct sockaddr_in sin;
	int temp;
	UDPTransport *transport;
	NSHost *newAddress;
	
	temp = sizeof(struct sockaddr_in);
	
	if ((newDesc = accept(desc, (struct sockaddr *)&sin, 
	    &temp)) == -1)
	{
		[NSException raise: FatalNetException
		  format: @"%s", strerror(errno)];
	}
	
	newAddress = [[UDPSystem sharedInstance] 
	  hostFromNetworkOrderInteger: sin.sin_addr.s_addr];	

	transport = AUTORELEASE([[UDPTransport alloc] 
	  initWithDesc: newDesc
	  withRemoteHost: newAddress]);
	
	if (!transport)
	{
		close(newDesc);
		return self;
	}
	
	[AUTORELEASE([netObjectClass new]) connectionEstablished: transport];
	
	return self;
}
/**
 * Returns the port that this UDPPort is currently bound to.
 */
- (uint16_t)port
{
	return port;
}
@end

static NetApplication *net_app = nil; 

/**
 * Handles the actual TCP/IP transfer of data.
 */
@implementation UDPTransport
+ (void)initialize
{
	net_app = RETAIN([NetApplication sharedInstance]);
}
/** 
 * Initializes the transport with the file descriptor <var>aDesc</var>.
 * <var>theAddress</var> is the host that the flie descriptor is connected
 * to.
 */
- initWithDesc: (int)aDesc withRemoteHost: (NSHost *)theAddress
{
	struct sockaddr_in x;
	socklen_t address_length = sizeof(x);

	if (!(self = [super init])) return nil;
	
	desc = aDesc;
	
	writeBuffer = RETAIN([NSMutableData dataWithCapacity: 2000]);
	remoteHost = RETAIN(theAddress);
	
	if (getsockname(desc, (struct sockaddr *)&x, &address_length) != 0) 
	{
		[[UDPSystem sharedInstance]
		  setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		[self release];
		return nil;
	}
	
	localHost = RETAIN([[UDPSystem sharedInstance] 
	  hostFromNetworkOrderInteger: x.sin_addr.s_addr]);
	
	connected = YES;
	
	return self;
}
- (void)dealloc
{
	[self close];
	RELEASE(writeBuffer);
	RELEASE(localHost);
	RELEASE(remoteHost);

	[super dealloc];
}
#define READ_BLOCK_SIZE 10000
/**
 * Handles the actual reading of data from the connection.
 * Throws an exception if an error occurs while reading data.
 * If <var>maxDataSize</var> is <= 0, all possible data will be
 * read.
 */
- (NSData *)readData: (int)maxDataSize
{
	char *buffer;
	int readReturn;
	NSMutableData *data;
	int remaining;
	int bufsize;
	fd_set readSet;
	int toRead;
	struct timeval zeroTime = { 0, 0 };
	
	if (!connected)
	{
		[NSException raise: FatalNetException
		  format: @"Not connected"];
	}
	
	if (maxDataSize <= 0)
	{
		remaining = -1;
		bufsize = READ_BLOCK_SIZE;
	}
	else
	{
		remaining = maxDataSize;
		bufsize = (READ_BLOCK_SIZE < remaining ? READ_BLOCK_SIZE : remaining);
	}
	
	buffer = malloc(bufsize);
	if (!buffer)
	{
		[NSException raise: NSMallocException 
		  format: @"%s", strerror(errno)];
	}
	data = [NSMutableData dataWithCapacity: bufsize];
	
	do
	{
		if (remaining == -1)
		{
			toRead = bufsize;
		}
		else
		{
			toRead = bufsize < remaining ? bufsize : remaining;
		}

		readReturn = read(desc, buffer, toRead); 
		if (readReturn == 0)
		{
			free(buffer);
			[NSException raise: NetException
			  format: @"Socket closed"];
		}

		if (readReturn == -1)
		{
			free(buffer);
			[NSException raise: FatalNetException
			  format: @"%s", strerror(errno)];
		}

		[data appendBytes: buffer length: readReturn];
		
		if (readReturn < bufsize)
		{
			break;
		}

		if (remaining != -1)
		{
			remaining -= readReturn;
			if (remaining == 0)
			{
				break;
			}
		}
		
		FD_ZERO(&readSet);
		FD_SET(desc, &readSet);
		select(desc + 1, &readSet, NULL, NULL, &zeroTime);

	} while (FD_ISSET(desc, &readSet));
		
	free(buffer);
	
	return data;
}
#undef READ_BLOCK_SIZE
/**
 * Returns YES if there is no more data to write in the buffer and NO if 
 * there is.
 */
- (BOOL)isDoneWriting
{
	if (!connected)
	{
		[NSException raise: FatalNetException
		  format: @"Not connected"];
	}
	return ([writeBuffer length]) ? NO : YES;
}
/**
 * If <var>aData</var> is nil, this will physically transport the data
 * to the connected end.  Otherwise this will put the data in the buffer of 
 * data that needs to be written to the connection when next possible.
 */
- writeData: (NSData *)aData
{
	int writeReturn;
	char *bytes;
	int length;
	
	if (aData)
	{
		if ([writeBuffer length] == 0)
		{
			[net_app transportNeedsToWrite: self];
		}
		[writeBuffer appendData: aData];
		return self;
	}
	if (!connected)
	{
		[NSException raise: FatalNetException
		  format: @"Not connected"];
	}
	
	if ([writeBuffer length] == 0)
	{
		return self;
	}
	
	writeReturn = 
	  write(desc, [writeBuffer mutableBytes], [writeBuffer length]);

	if (writeReturn == -1)
	{
		[NSException raise: FatalNetException
		  format: @"%s", strerror(errno)];
	}
	if (writeReturn == 0)
	{
		return self;
	}
	
	bytes = (char *)[writeBuffer mutableBytes];
	length = [writeBuffer length] - writeReturn;
	
	memmove(bytes, bytes + writeReturn, length);
	[writeBuffer setLength: length];
	
	return self;
}
/**
 * Returns a NSHost of the local side of a connection.
 */
- (NSHost *)localHost
{
	return localHost;	
}
/** 
 * Returns a NSHost of the remote side of a connection.
 */
- (NSHost *)remoteHost
{
	return remoteHost;
}
/**
 * Returns the low level file descriptor that is used internally.
 */
- (int)desc
{
	return desc;
}
/**
 * Closes the transport nd makes sure there is no more incoming or outgoing
 * data on the connection.
 */
- (void)close
{
	if (!connected)
	{
		return;
	}
	connected = NO;
	close(desc);
}
@end	

