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

#import "IRCBot.h"
#import <netclasses/NetTCP.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSHost.h>

#include <time.h>
#include <stdlib.h>

int main(int argc, char **argv, char **env)
{
	id connection;
	NSMutableArray *anArray;
	FILE *aFile;
	char buffer[5000];
	CREATE_AUTORELEASE_POOL(arp);

	srand(time(0) ^ gethostid() % getpid());
		
	NSLog(@"Connecting to irc.freenode.net 6667...");
	
	anArray = [NSMutableArray new];
	aFile = fopen("nicks.txt", "r");
	while (!feof(aFile))
	{
		fscanf(aFile, "%4999[^\n]%*c", buffer);
		buffer[4999] = 0;
		[anArray addObject: [NSString stringWithCString: buffer]];
	}
	[anArray addObject: @"FIXME"];

	connection = [[IRCBot alloc] 
	  initWithNickname: @"LiveCDCount"
	  withUserName: nil withRealName: @"Andy Ruder"
	  withPassword: nil];
	  
	[connection setNameList: anArray];
	NSLog(@"anArray: %@", anArray);
	RELEASE(anArray);

	[[TCPSystem sharedInstance] connectNetObjectInBackground: connection 
	  toHost: [NSHost hostWithName: @"irc.freenode.net"] 
	  onPort: 6667 withTimeout: 30];
	
	NSLog(@"Connection being established...");
	
	[[NSRunLoop currentRunLoop] run];
		
	RELEASE(arp);
	return 0;
}

