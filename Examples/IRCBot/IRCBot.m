/***************************************************************************
                                IRCBot.m
                          -------------------
    begin                : Wed Jun  5 03:28:59 UTC 2002
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
#import <Foundation/NSTimer.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSValue.h>

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

@implementation IRCBot
- connectionEstablished: aTransport
{
	fileData = [NSMutableData new];
	return [super connectionEstablished: aTransport];
}
- (void)connectionLost
{
	DESTROY(fileData);
	[super connectionLost];
}
- registeredWithServer
{
	[self joinChannel: 
	  @"#gnustep,#netclasses" 
	  withPassword: nil];
	return self;
}
- CTCPRequestReceived: (NSString *)aCTCP withArgument: (NSString *)argument
    from: (NSString *)aPerson
{
	aCTCP = [aCTCP uppercaseIRCString];

	if ([aCTCP compare: @"PING"] == NSOrderedSame)
	{
		[self sendCTCPReply: @"PING" withArgument: argument
		  to: ExtractIRCNick(aPerson)];
	}
	if ([aCTCP compare: @"VERSION"] == NSOrderedSame)
	{
		[self sendCTCPReply: @"VERSION" withArgument: @"netclasses:0.992:GNUstep"
		  to: ExtractIRCNick(aPerson)];
	}

	return self;
}		
- messageReceived: (NSString *)aMessage to: (NSString *)to
               from: (NSString *)whom
{
	NSString *sendTo = ExtractIRCNick(whom);
	
	if ([nick caseInsensitiveCompare: to] != NSOrderedSame)
	{
		return self;  // Only accepts private messages
	}
		
	if ([aMessage caseInsensitiveCompare: @"quit"] == NSOrderedSame)
	{
		[self sendMessage: @"Quitting..." to: sendTo];
		[self quitWithMessage: 
		  [NSString stringWithFormat: @"Quit requested by %@", sendTo]];
		return self;
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
		
		fortune = popen("fortune", "r");
		
		do
		{
			read = fread([input mutableBytes], sizeof(char), 4000, fortune);
			while ((line = chomp_line(input))) 
			{
				[self sendMessage: [NSString stringWithCString: [line bytes]
				  length: [line length]] to: sendTo];
			}
		}
		while(read == 4000);

		[self sendMessage: [NSString stringWithCString: [line bytes]
		  length: [line length]] to: sendTo];
		
		pclose(fortune);
		return self;
	}
	
	return self;
}
- DCCSendRequestReceived: (NSDictionary *)fileInfo from: (NSString *)sender
{
	NSLog(@"DCC: %@(%@:%@) wants to send %@ (%@ bytes)",
	 sender, [fileInfo objectForKey: DCCInfoHost],
	 [fileInfo objectForKey: DCCInfoPort],
	 [fileInfo objectForKey: DCCInfoFileName],
	 [fileInfo objectForKey: DCCInfoFileSize]);
	
	if (dcc)
	{
		return self;
	}
	
	dcc = [[DCCReceiveObject alloc] initWithReceiveOfFile: fileInfo
	  withDelegate: self
	  withTimeout: 30
	  withUserInfo: [NSDictionary dictionaryWithObject: ExtractIRCNick(sender)
	    forKey: @"from:"]];
	return self;
}
- DCCInitiated: aConnection
{
	return self;
}
- DCCStatusChanged: (NSString *)aStatus forObject: aConnection
{
	NSLog(@"DCC: Status change to %@", aStatus);
	return self;
}
- DCCReceivedData: (NSData *)data forObject: aConnection
{
	[fileData appendData: data];
	return self;
}
- DCCNeedsMoreData: aConnection
{
	if ([fileData length] > 0)
	{
		[aConnection writeData: fileData];
		[fileData setLength: 0];
		[aConnection writeData: nil]; // Tells it that all data is sent
	}
	
	return self;
}
- DCCDone: aConnection // Only one DCC going at a time so aConnection == dcc
{
	if ([aConnection isKindOf: [DCCReceiveObject class]])
	{
		id info;
		if ([fileData length] == 0)
		{
			DESTROY(dcc);
			return self;
		}
		
		NSLog(@"DCC: Receive complete, sending back");
		info = [dcc info];
		dcc = [[DCCSendObject alloc] 
		 initWithSendOfFile:
		  [[info objectForKey: DCCInfoFileName] stringByAppendingString: @"2"]
		 withSize: [NSNumber numberWithUnsignedLong: [fileData length]]
		 withDelegate: self
		 withTimeout: 15
		 withBlockSize: 1024
		 withUserInfo: nil];

		[self sendDCCSendRequest: [dcc info] to: [[aConnection userInfo]
		    objectForKey: @"from:"]];
		RELEASE(aConnection);
	}
	else
	{
		DESTROY(dcc);
	}
		 
	return self;
}
@end
