/***************************************************************************
                                LineObject.m
                          -------------------
    begin                : Thu May 30 02:19:30 UTC 2002
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
 * <title>LineObject class reference</title>
 * <author name="Andrew Ruder">
 * 	<email address="aeruder@ksu.edu" />
 * 	<url url="http://aeruder.gnustep.us/index.html" />
 * </author>
 * <version>Revision 1</version>
 * <date>November 8, 2003</date>
 * <copy>Andrew Ruder</copy>
 */

#import "LineObject.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#include <string.h>

static inline NSData *chomp_line(NSMutableData *data)
{
	char *memory = [data mutableBytes];
	char *memoryEnd = memory + [data length];
	char *lineEndWithControls;
	char *lineEnd;
	int tempLength;
	
	id lineData;
	
	lineEndWithControls = lineEnd = 
	  memchr(memory, '\n', memoryEnd - memory);
	
	if (!lineEnd)
	{
		return nil;
	}
	
	while (((*lineEnd == '\n') || (*lineEnd == '\r'))
	       && (lineEnd >= memory))
	{
		lineEnd--;
	}

	lineData = [NSData dataWithBytes: memory length: lineEnd - memory + 1];
	
	tempLength = memoryEnd - lineEndWithControls - 1;
	
	memmove(memory, lineEndWithControls + 1, 
	        tempLength);
	
	[data setLength: tempLength];
	
	return lineData;
}

/**
 * LineObject is used for line-buffered connections (end in \r\n or just \n).
 * To use, simply override lineReceived: in a subclass of LineObject.  By
 * default, LineObject does absolutely nothing with lineReceived except throw
 * the line away.  Use line object if you simply want line-buffered input.
 * This can be used on IRC, telnet, etc.
 */

@implementation LineObject
/**
 * Cleans up the instance variables and closes/releases the transport.
 */
- (void)connectionLost
{
	[transport close];
	DESTROY(transport);
	RELEASE(_readData);
}
/**
 * Initializes data and retains <var>aTransport</var>
 * <var>aTransport</var> should conform to the [(NetTransport)]
 * protocol.
 */
- connectionEstablished: (id <NetTransport>)aTransport
{
	transport = RETAIN(aTransport);
	[[NetApplication sharedInstance] connectObject: self];
	
	_readData = [NSMutableData new];

	return self;
}
/**
 * Adds the data to a buffer.  Then calls -lineReceived: for all
 * full lines currently in the buffer.  Don't override this, override
 * -lineReceived:.
 */
- dataReceived: (NSData *)newData
{
	id newLine;
	
	[_readData appendData: newData];
	
	while ((newLine = chomp_line(_readData))) [self lineReceived: newLine];
	
	return self;
}
/**
 * Returns the transport
 */
- (id <NetTransport>)transport
{
	return transport;
}
/**
 * <override-subclass />
 * <var>aLine</var> contains a full line of text (without the ending newline)
 */
- lineReceived: (NSData *)aLine
{
	return self;
}
@end	
