/***************************************************************************
                                EchoServ.h
                          -------------------
    begin                : Sun Apr 28 21:18:22 UTC 2002
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
#import "NetBase.h"
#import <Foundation/NSObject.h>

@class NSData;

@interface EchoServ : NSObject < NetObject >
	{
		id transport;
	}
- (void)connectionLost;
- connectionEstablished: aTransport;
- dataReceived: (NSData *)data;
- (id)transport;
@end

