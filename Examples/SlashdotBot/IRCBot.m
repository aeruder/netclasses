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
#import <Foundation/NSScanner.h>

#include <string.h>
#include <stdio.h>
#include <unistd.h>

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
- (void)setNameList: (NSArray *)aList
{
	nameList = RETAIN(aList);
}
- lineReceived: (NSData *)aLine
{
	NSLog(@"%@", [NSString stringWithCString: [aLine bytes] length: [aLine length]]);
	return [super lineReceived: aLine];
}
- connectionEstablished: aTransport
{
	return [super connectionEstablished: aTransport];
}
- (void)connectionLost
{
	[super connectionLost];
}
- registeredWithServer
{
	[self joinChannel: 
	  @"#gnustep" 
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
		[self sendCTCPReply: @"VERSION" withArgument: @"netclasses:1.03pre2:GNUstep"
		  to: ExtractIRCNick(aPerson)];
	}

	return self;
}		
- (void)requestTopic: (NSTimer *)aTimer
{
	[self setTopicForChannel: @"#gnustep" to: nil];
	currentTimer = nil;
}
- (id)channelJoined: (NSString *)aChannel from: (NSString *)aJoiner
{
	NSString *nickN = ExtractIRCNick(aJoiner);
	NSString *host = ExtractIRCHost(aJoiner);

	if ([host hasPrefix: @"~gnustep"] && [nameList containsObject: nickN])
	{
		[self sendNotice: @"Welcome to GNUstep LiveCD" to: nickN];
		[self sendNotice: @"You are now connected to the #gnustep IRC channel" to: nickN];
		count++;
		if (currentTimer)
		{
			[currentTimer invalidate];
		}
		currentTimer = [NSTimer scheduledTimerWithTimeInterval: 60.0 target: self 
		  selector: @selector(requestTopic:) userInfo: nil repeats: NO];
	}

	return self;
}
- numericCommandReceived: (NSString *)aCommand withParams: (NSArray *)paramList
  from: (NSString *)aSender
{
	NSScanner *aScanner;
	NSLog(@"%@", paramList);
	if ([aCommand isEqualToString: RPL_TOPIC] && [[paramList objectAtIndex: 0] isEqualToString: @"#gnustep"] && count)
	{
		BOOL res;
		id topic;
		topic = [paramList objectAtIndex: [paramList count] - 1];
		aScanner = [NSScanner scannerWithString: topic];
		[aScanner setCaseSensitive: NO];
		NSLog(@"Scanning...");
		[aScanner scanUpToString: @"LiveCD count: " intoString: 0];
		res = [aScanner scanString: @"LiveCD count: " intoString: 0];
		if (res)
		{
			int startIndex, stopIndex;
			int count2;
			id newString;
			NSLog(@"Found valid string");

			startIndex = [aScanner scanLocation];
			if (![aScanner scanInt: &count2])
			{
				count2 = 0;
			}
			stopIndex = [aScanner scanLocation];

			newString = [NSMutableString stringWithString: topic];
			[newString replaceCharactersInRange: 
			  NSMakeRange(startIndex, stopIndex - startIndex) 
			  withString: [NSString stringWithFormat: @"%d", count2 + count]];
			count = 0;
			NSLog(@"New topic: newString: %@", newString);

			[self setTopicForChannel: @"#gnustep" to: newString];
		}
	}
	return self;
}
- pingReceivedWithArgument: (NSString *)anArgument from: (NSString *)aSender
{
	NSLog(@"ping received: %@", anArgument);
	[self sendPongWithArgument: anArgument];
	return self;
}
- messageReceived: (NSString *)aMessage to: (NSString *)to
               from: (NSString *)whom
{
	NSString *sendTo = ExtractIRCNick(whom);
	
	if ([nick caseInsensitiveCompare: to] != NSOrderedSame)
	{
		if ([aMessage isEqualToString: @"killfixme"] || [aMessage isEqualToString: @"startthebomb"])
		{
			[self sendMessage: @"recover fixme somepass" to: @"NickServ"];
			[self sendMessage: @"release fixme somepass" to: @"NickServ"];
			[self sendMessage: @"FIXME ELIMINATED!!!!" to: to];
			[self setNick: nick];
		}
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
@end
