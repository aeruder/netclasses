/***************************************************************************
                              SimpleClient.m
                          -------------------
	begin                : Tue Feb 17 00:06:15 CST 2004
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

#import "SimpleClient.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h> 
#import <Foundation/NSHost.h>
#import <Foundation/NSCharacterSet.h>

@implementation SimpleClient
- (void)connectionLost
{
	[transport close];
	DESTROY(transport);
}
- connectionEstablished: aTransport
{
	transport = RETAIN(aTransport);

	[[NetApplication sharedInstance] connectObject: self];

	return self;
}
- dataReceived: (NSData *)data
{
	NSString *aString = [NSString stringWithCString: [data bytes] 
	  length: [data length]];

	aString = [aString stringByTrimmingCharactersInSet: [NSCharacterSet
	  whitespaceAndNewlineCharacterSet]];

	NSLog(@"Received data: %@", aString);

	return self;
}
- transport
{
	return transport;
}
@end													   
