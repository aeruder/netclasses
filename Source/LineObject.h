/***************************************************************************
                                LineObject.h
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

@class LineObject;

#ifndef LINE_OBJECT_H
#define LINE_OBJECT_H

#import "NetBase.h"
#import <Foundation/NSObject.h>

@class NSMutableData, NSData;

@interface LineObject : NSObject < NetObject >
	{
		id transport;
		NSMutableData *_readData;
	}
- (void)connectionLost;
- connectionEstablished: (id <NetTransport>)aTransport;
- dataReceived: (NSData *)newData;
- (id <NetTransport>)transport;

- lineReceived: (NSData *)aLine;
@end

#endif
