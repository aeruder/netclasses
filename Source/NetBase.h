/***************************************************************************
                                NetBase.h
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

@class NetApplication;

#ifndef NET_BASE_H
#define NET_BASE_H

#import <Foundation/NSObject.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSMapTable.h>

#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

@class NSData, NSNumber, NSMutableDictionary, NSDictionary, NSArray;
@class NSMutableArray, NSString;

/**
 * A protocol used for the actual transport class of a connection.  A
 * transport is a low-level object which actually handles the physical
 * means of transporting data to the other side of the connection through
 * methods such as -readData: and -writeData:.
 */
@protocol NetTransport <NSObject>
/**
 * Returns an object representing the local side of a connection.  The actual
 * object depends on the implementation of this protocol.
 */
- (id)localHost;
/**
 * Returns an object representing the remote side of a connection.  The actual
 * object depends on the implementation of this protocol.
 */
- (id)remoteHost;
/**
 * This should serve two purposes.  When <var>data</var> is not nil,
 * the transport should store the data, and then call 
 * [NetApplication-transportNeedsToWrite:] to notify [NetApplication]
 * that the transport needs to write.
 *
 * When <var>data</var> is nil, the transport should assume that it is
 * actually safe to write the data and should do so at this time.  
 * [NetApplication] will call -writeData: with a nil argument when it is 
 * safe to write
 */
- writeData: (NSData *)data;
/**
 * Return YES if no more data is waiting to be written, and NO otherwise.
 * Used by [NetApplication] to determine when it can stop checking 
 * the transport for writing availability.
 */
- (BOOL)isDoneWriting;
/**
 * Called by [NetApplication] when it is safe to write.  Should return
 * data read from the connection with a maximum size of 
 * <var>maxReadSize</var>.  If <var>maxReadSize</var> should be zero, all
 * data available on the connection should be returned.
 */
- (NSData *)readData: (int)maxReadSize;
/**
 * Returns a file descriptor representing the connection.
 */
- (int)desc;
/**
 * Should close the file descriptor.
 */
- (void)close;
@end

/**
 * Represents a class that acts as a port.  Each port allows a object type
 * to be attached to it, and it will instantiate an object of that type
 * upon receiving a new connection.
 */
@protocol NetPort <NSObject>
/**
 * Sets the class of the object that should be attached to the port.  This
 * class should implement the [(NetObject)] protocol.
 */
- setNetObject: (Class)aClass;
/**
 * Called when the object has [NetApplication-disconnectObject:] called on it.
 */
- (void)connectionLost;
/**
 * Called when a new connection has been detected by [NetApplication].
 * The port should should use this new connection to instantiate a object
 * of the class set by -setNetObject:.
 */
- newConnection;
/**
 * Returns the low-level file descriptor.
 */
- (int)desc;
/**
 * Should close the file descriptor.
 */
- (void)close;
@end

/**
 * This protocol should be implemented by an object used in a connection.
 * When a connection is received by a [(NetPort)], the object attached to
 * the port is created and given the transport.
 */
@protocol NetObject <NSObject>
/**
 * Called when [NetApplication-disconnectObject:] is called with this
 * object as a argument.  This object will no longer receive data or other
 * messages after it is disconnected.
 */
- (void)connectionLost;
/**
 * Called when a connection has been established, and gives the object
 * the transport used to actually transport the data.  <var>aTransport</var>
 * will implement [(NetTransport)].
 */
- connectionEstablished: (id <NetTransport>)aTransport;
/**
 * <var>data</var> is data read in from the connection.
 */
- dataReceived: (NSData *)data;
/**
 * Should return the transport given to the object by -connectionEstablished:
 */
- (id <NetTransport>)transport;
@end

/**
 * Thrown when a recoverable exception occurs on a connection or otherwise.
 */
extern NSString *NetException;
/**
 * Should be thrown when a non-recoverable exception occurs on a connection.
 * The connection should be closed immediately.
 */
extern NSString *FatalNetException;

#ifdef __APPLE__
/**
 * Used for OS X compatibility.  This type is an extension to GNUstep.  On
 * OS X, a compatibility layer is created to recreate the GNUstep extensions
 * using OS X extensions.
 */
typedef enum { ET_RDESC, ET_WDESC, ET_RPORT, ET_EDESC } RunLoopEventType;
/** 
 * Used for OS X compatibility.  OS X does not have the RunLoopEvents
 * protocol.  This is a GNUstep-specific extension.  This must be
 * recreated on OS X to compile netclasses.
 */
@protocol RunLoopEvents
/**
 * OS X compatibility function.  This is a callback called by the run loop
 * when an event has timed out.
 */
- (NSDate *)timedOutEvent: (void *)data 
                     type: (RunLoopEventType)type
                  forMode: (NSString *)mode;
/**
 * OS X compatibility function.  This is a callback called by the run loop
 * when an event has been received.
 */
- (void)receivedEvent: (void *)data
                  type: (RunLoopEventType)type
                 extra: (void *)extra
               forMode: (NSString *)mode;
@end
#endif

@interface NetApplication : NSObject < RunLoopEvents >
	{
		NSMutableArray *portArray;
		NSMutableArray *netObjectArray;
		NSMutableArray *badDescs;
		NSMapTable *descTable;
	}
+ sharedInstance;
/**
 * Should not be called.  Used internally by [NetApplication] to receive
 * timed out events notifications from the runloop.
 */
- (NSDate *)timedOutEvent: (void *)data 
                     type: (RunLoopEventType)type
                  forMode: (NSString *)mode;
/**
 * Should not be called.  Used internally by [NetApplication] to receive
 * events from the runloop.
 */
- (void)receivedEvent: (void *)data
                  type: (RunLoopEventType)type
                 extra: (void *)extra
               forMode: (NSString *)mode;
													 
- transportNeedsToWrite: (id <NetTransport>)aTransport;

- connectObject: anObject;
- disconnectObject: anObject;
- closeEverything;
@end

#endif
