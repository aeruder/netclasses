/***************************************************************************
                                IRCBot.h
                          -------------------
    begin                : Wed Jun  5 03:28:59 UTC 2002
    copyright            : (C) 2002 by Andy Ruder
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

#import "IRCClient.h"

@class NSString;

@interface IRCBot : IRCClient
	{
	}
- registeredWithServer;
- messageReceived: (NSString *)aMessage to: (NSString *)to
               from: (NSString *)whom;
@end
