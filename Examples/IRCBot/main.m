/***************************************************************************
                                main.m
                          -------------------
    begin                : Sun Apr 28 21:18:23 UTC 2002
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

#include "NetTCP.h"
#include "IRCBot.h"
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSHost.h>

#include <time.h>

int main(int argc, char **argv, char **env)
{
	id connection;
	CREATE_AUTORELEASE_POOL(arp);

	srand(time(0) ^ gethostid() % getpid());
		
	NSLog(@"Connecting to irc.openprojects.net 6667...");
	
	connection = [[IRCBot alloc] 
	  initWithNickname: @"Niles"
	  withUserName: nil withRealName: @"Andy Ruder"
	  withPassword: nil];
	  
	[[TCPSystem sharedInstance] connectNetObjectInBackground: connection 
	  toHost: [NSHost hostWithName: @"irc.freenode.net"] 
	  onPort: 6667 withTimeout: 30];
	
	NSLog(@"Connection being established...");
	
	[[NSRunLoop currentRunLoop] run];
		
	RELEASE(arp);
	return 0;
}

