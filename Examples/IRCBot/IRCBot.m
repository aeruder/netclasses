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
	[self joinChannel: 
	  @"#gnustep,#netclasses" 
	  withPassword: nil];
	return self;
}
- versionRequestReceived: (NSString *)query from: (NSString *)aPerson
{
	[self sendVersionReplyTo: ExtractIRCNick(aPerson) name: @"netclasses"
	 version: @"0.93c"  environment: @"GNUstep, silly!!!"];
	return self;
}
- pingRequestReceived: (NSString *)argument from: (NSString *)aPerson
{
	[self sendPingReplyTo: ExtractIRCNick(aPerson) withArgument: argument];
	return self;
}
- messageReceived: (NSString *)aMessage to: (NSString *)to
               from: (NSString *)whom
{
	NSString *sendTo = ExtractIRCNick(whom);
	
	NSLog(@"%@/%@> %@", sendTo, to, aMessage);
	
	if ([nick caseInsensitiveCompare: to] != NSOrderedSame)
	{
		return self;  // Only accepts private messages
	}
		
	if ([aMessage caseInsensitiveCompare: @"quit"] == NSOrderedSame)
	{
		[self sendMessage: @"Quitting..." to: sendTo];
		[self quitWithMessage: 
		  [NSString stringWithFormat: @"Quit requested by %@", sendTo]];
	}
	else if ([aMessage caseInsensitiveCompare: @"fortune"] == NSOrderedSame)
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
