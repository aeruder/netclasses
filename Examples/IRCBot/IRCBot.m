/***************************************************************************
                                IRCBot.m
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

#import "IRCBot.h"
#import <Foundation/NSTimer.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>

@implementation IRCBot
- registeredWithServer
{
	[super registeredWithServer];
	[self joinChannel: @"#gnustep" withPassword: nil];
	return self;
}
- messageReceived: (NSString *)aMessage from: (NSString *)from
               to: (NSString *)to
{
	NSString *sendTo;
	
	if ([nick caseInsensitiveCompare: to] == NSOrderedSame)
	{
		sendTo = ExtractIRCNick(from);
	}
	else
	{
		sendTo = to;
	}
	
	if ([aMessage caseInsensitiveCompare: @"quit now"] == NSOrderedSame)
	{
		[self sendAction: @"cries" to: sendTo];
		[self quitWithMessage: @"Fine!!!"];
	}
	if ([aMessage caseInsensitiveCompare: @"fortune"] == NSOrderedSame)
	{
		if (sendTo == to)
		{
			return self;
		}
		int read;
		FILE *fortune;
		NSMutableData *input = [NSMutableData dataWithLength: 4000];
		id line;
		
		fortune = popen("fortune -o", "r");
		
		do
		{
			read = fread([input mutableBytes], sizeof(char), 4000, fortune);
			while ((line = ChompLine(input))) 
			{
				[self sendMessage: [NSString stringWithCString: [line bytes]
				  length: [line length]] to: sendTo];
			}
		}
		while(read == 4000);

		[self sendMessage: [NSString stringWithCString: [line bytes]
		  length: [line length]] to: sendTo];
		
		pclose(fortune);
	}
	return self;
}
@end
