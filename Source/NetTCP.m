/***************************************************************************
                                NetTCP.m
                          -------------------
    begin                : Fri Nov  2 01:19:16 UTC 2001
    copyright            : (C) 2003 by Andy Ruder
    email                : aeruder@yahoo.com
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
/**
 * <title>NetTCP reference</title>
 * <author name="Andrew Ruder">
 * 	<email address="aeruder@ksu.edu" />
 * 	<url url="http://aeruder.gnustep.us/index.html" />
 * </author>
 * <version>Revision 1</version>
 * <date>November 8, 2003</date>
 * <copy>Andrew Ruder</copy>
 */

#import "NetTCP.h"
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

#ifdef __APPLE__
#ifndef socklen_t
typedef int socklen_t;
#endif
#endif

/**
 * If an error occurs and error number is zero, this could be the error string.
 * This error occurs when some operation times out.
 */
NSString *NetclassesErrorTimeout = @"Connection timed out";
/**
 * Could be the current error string if the error number is zero and some
 * error has occurred.  Indicates
 * that a NSHost returned an address that was invalid.
 */
NSString *NetclassesErrorBadAddress = @"Bad address";
/**
 * The error message used when a connection is aborted.
 */
NSString *NetclassesErrorAborted = @"Connection aborted";

static TCPSystem *default_system = nil;

@interface TCPSystem (InternalTCPSystem)
- (int)openPort: (uint16_t)portNumber;
- (int)openPort: (uint16_t)portNumber onHost: (NSHost *)aHost;

- (int)connectToHost: (NSHost *)aHost onPort: (uint16_t)portNumber
         withTimeout: (int)timeout inBackground: (BOOL)background;

- setErrorString: (NSString *)anError withErrno: (int)aErrno;
@end

@interface TCPConnecting (InternalTCPConnecting)
- initWithNetObject: (id <NetObject>)netObject withTimeout: (int)aTimeout;
- connectingFailed: (NSString *)error;
- connectingSucceeded;
- timeoutReceived: (NSTimer *)aTimer;
@end
	
@interface TCPConnectingTransport : NSObject < NetTransport >
	{
		BOOL connected;
		int desc;
		NSHost *remoteHost;
		NSHost *localHost;
		NSMutableData *writeBuffer;
		TCPConnecting *owner;	
	}
- (NSMutableData *)writeBuffer;

- initWithDesc: (int)aDesc withRemoteHost: (NSHost *)theAddress
     withOwner: (TCPConnecting *)anObject;
	 
- (void)close;

- (NSData *)readData: (int)maxDataSize;
- (BOOL)isDoneWriting;
- writeData: (NSData *)data;

- (NSHost *)remoteHost;
- (NSHost *)localHost;
- (int)desc;
@end

@implementation TCPConnectingTransport
- (NSMutableData *)writeBuffer
{
	return writeBuffer;
}
- initWithDesc: (int)aDesc withRemoteHost: (NSHost *)theAddress 
     withOwner: (TCPConnecting *)anObject
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
		[[TCPSystem sharedInstance]
		  setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		[self dealloc];
		return nil;
	}
	
	localHost = RETAIN([[TCPSystem sharedInstance] 
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
		[writeBuffer appendData: data];
		return self;
	}
	
	if (recv(desc, buffer, sizeof(buffer), MSG_PEEK) == -1)
	{
		if (errno != EAGAIN)
		{
			[owner connectingFailed: [NSString stringWithFormat: @"%s", 
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

@implementation TCPConnecting (InternalTCPConnecting)
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
	if ([netObject conformsToProtocol: @protocol(TCPConnecting)])
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
	id newTrans = AUTORELEASE([[TCPTransport alloc] initWithDesc:
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
@implementation TCPConnecting
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
 * [(TCPConnecting)] protocol, it will receive a 
 * [(TCPConnecting)-connectingFailed:] message with a argument of
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
 * [(TCPConnecting)], it will receive a 
 * [(TCPConnecting)-connectingStarted:] with the instance of TCPConnecting
 * as an argument.
 */
- connectionEstablished: (id <NetTransport>)aTransport
{
	transport = RETAIN(aTransport);	
	[[NetApplication sharedInstance] connectObject: self];
	if ([netObject conformsToProtocol: @protocol(TCPConnecting)])
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

@implementation TCPSystem (InternalTCPSystem)
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
	
	if (!aHost)
	{
		sin.sin_addr.s_addr = htonl(INADDR_ANY);
	}
	else
	{
		if (inet_aton([[aHost address] cString], 
		    (struct in_addr *)(&(sin.sin_addr))) == 0)
		{
			[self setErrorString: NetclassesErrorBadAddress withErrno: 0];
			return -1;
		}	      
	}
	
	sin.sin_port = htons(portNumber);
	sin.sin_family = AF_INET;
	
	if ((myDesc = socket(AF_INET, SOCK_STREAM, 0)) == -1)
	{
		[self setErrorString: [NSString stringWithFormat: @"%s", 
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	temp = 1;
	if (setsockopt(myDesc, SOL_SOCKET, SO_REUSEADDR, 
	               &temp, sizeof(temp)) == -1)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	if (bind(myDesc, (struct sockaddr *) &sin, sizeof(struct sockaddr)) < 0)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	temp = 1;
	if (setsockopt(myDesc, SOL_SOCKET, SO_KEEPALIVE, 
	               &temp, sizeof(temp)) == -1)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}
	if (listen(myDesc, 5) == -1)
	{
		close(myDesc);
		[self setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		return -1;
	}

	return myDesc;
}
- (int)connectToHost: (NSHost *)host onPort: (uint16_t)portNumber 
       withTimeout: (int)timeout inBackground: (BOOL)bck
{
	int myDesc;
	struct sockaddr_in destAddr;

	if (!host)
	{
		[self setErrorString: NetclassesErrorBadAddress withErrno: 0];
		return -1;
	}
	
	if ((myDesc = socket(AF_INET, SOCK_STREAM, 0)) == -1)
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
	if (connect(myDesc, (struct sockaddr *)&destAddr, sizeof(destAddr)) == -1)
	{
		if (errno == EINPROGRESS) // Need to work with timeout now.
		{
			fd_set fdset;
			struct timeval selectTime;
			int selectReturn;

			if (bck)
			{
				return myDesc;
			}
			
			FD_ZERO(&fdset);
			FD_SET(myDesc, &fdset);

			selectTime.tv_sec = timeout;
			selectTime.tv_usec = 0;

			selectReturn = select(myDesc + 1, 0, &fdset, 0, &selectTime);

			if (selectReturn == -1)
			{
				[self setErrorString: [NSString stringWithFormat: @"%s",
				  strerror(errno)] withErrno: errno];
				close(myDesc);
				return -1;
			}
			if (selectReturn > 0)
			{
				char buffer[1];
				if (recv(myDesc, buffer, sizeof(buffer), MSG_PEEK) == -1)
				{
					if (errno != EAGAIN)
					{
						[self setErrorString: [NSString stringWithFormat: @"%s",
						  strerror(errno)] withErrno: errno];
						close(myDesc);
						return -1;
					}
				}
			}
			else
			{
				[self setErrorString: NetclassesErrorTimeout
				  withErrno: 0];
				close(myDesc);
				return -1;
			}
		}
		else // connect failed with something other than EINPROGRESS
		{
			[self setErrorString: [NSString stringWithFormat: @"%s",
			  strerror(errno)] withErrno: errno];
			close(myDesc);
			return -1;
		}
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
@implementation TCPSystem
/**
 * Returns the one instance of TCPSystem currently in existence.
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
		[self dealloc];
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
	transport = AUTORELEASE([[TCPTransport alloc] initWithDesc: desc 
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
- (TCPConnecting *)connectNetObjectInBackground: (id <NetObject>)netObject 
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
	
	object = AUTORELEASE([[TCPConnecting alloc] initWithNetObject: netObject
	   withTimeout: aTimeout]);
	transport = AUTORELEASE([[TCPConnectingTransport alloc] initWithDesc: desc 
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
 * TCPPort is a class that is used to bind a descriptor to a certain
 * TCP/IP port and listen for connections.  When a connection is received,
 * it will create a class set with -setNetObject: and set it up with the new
 * connection.
 */
@implementation TCPPort
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
	
	desc = [[TCPSystem sharedInstance] openPort: aPort onHost: aHost];

	if (desc < 0)
	{
		[self dealloc];
		return nil;
	}
	if (getsockname(desc, (struct sockaddr *)&x, &address_length) != 0)
	{
		[[TCPSystem sharedInstance] setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		close(desc);
		[self dealloc];
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
	TCPTransport *transport;
	NSHost *newAddress;
	
	temp = sizeof(struct sockaddr_in);
	
	if ((newDesc = accept(desc, (struct sockaddr *)&sin, 
	    &temp)) == -1)
	{
		[NSException raise: FatalNetException
		  format: @"%s", strerror(errno)];
	}
	
	newAddress = [[TCPSystem sharedInstance] 
	  hostFromNetworkOrderInteger: sin.sin_addr.s_addr];	

	transport = AUTORELEASE([[TCPTransport alloc] 
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
 * Returns the port that this TCPPort is currently bound to.
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
@implementation TCPTransport
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
		[[TCPSystem sharedInstance]
		  setErrorString: [NSString stringWithFormat: @"%s",
		  strerror(errno)] withErrno: errno];
		[self dealloc];
		return nil;
	}
	
	localHost = RETAIN([[TCPSystem sharedInstance] 
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
/**
 * Handles the actual reading of data from the connection.
 * Throws an exception if an error occurs while reading data.
 */
- (NSData *)readData: (int)maxDataSize
{
	char *buffer;
	int readReturn;
	NSData *data;
	
	if (!connected)
	{
		[NSException raise: FatalNetException
		  format: @"Not connected"];
	}
	
	if (maxDataSize == 0)
	{
		return nil;
	}
	
	if (maxDataSize < 0)
	{
		[NSException raise: FatalNetException
		 format: @"Invalid number of bytes specified"];
	}
	
	buffer = malloc(maxDataSize + 1);
	readReturn = read(desc, buffer, maxDataSize);
	
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
	
	data = [NSData dataWithBytes: buffer length: readReturn];
	free(buffer);
	
	return data;
}
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

