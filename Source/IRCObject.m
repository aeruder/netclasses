/***************************************************************************
                                IRCObject.m
                          -------------------
    begin                : Thu May 30 22:06:25 UTC 2002
    copyright            : (C) 2005 by Andrew Ruder
    email                : aeruder@ksu.edu
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Lesser General Public License as        *
 *   published by the Free Software Foundation; either version 2.1 of the  *
 *   License or (at your option) any later version.                        *
 *                                                                         *
 ***************************************************************************/
/**
 * <title>IRCObject reference</title>
 * <author name="Andrew Ruder">
 * 	<email address="aeruder@ksu.edu" />
 * 	<url url="http://aeruder.gnustep.us/index.html" />
 * </author>
 * <version>Revision 1</version>
 * <date>November 8, 2003</date>
 * <copy>Andrew Ruder</copy>
 * <p>
 * Much of the information presented in this document is based off
 * of information presented in RFC 1459 (Oikarinen and Reed 1999).
 * This document is NOT aimed at reproducing the information in the RFC, 
 * and the RFC should still always be consulted for various server-related
 * replies to messages and proper format of the arguments.  In short, if you
 * are doing a serious project dealing with IRC, even with the use of 
 * netclasses, RFC 1459 is indispensable.
 * </p>
 */

#import "NetBase.h"
#import "NetTCP.h"
#import "IRCObject.h"

#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSScanner.h>

#include <string.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>

NSString *IRCException = @"IRCException";

static NSMapTable *command_to_function = 0;
static NSMapTable *ctcp_to_function = 0;

static NSData *IRC_new_line = nil;

/**
 * Additions of NSString that are used to upper/lower case strings taking
 * into account that on many servers {}|^ are lowercase forms of []\~.
 * Try not to depend on this fact, some servers nowadays are drifting away
 * from this idea and will treat them as different characters entirely.
 */
@implementation NSString (IRCAddition)
/**
 * Returns an uppercased string (and converts any of {}|^ characters found
 * to []\~ respectively).
 */
- (NSString *)uppercaseIRCString
{
	NSMutableString *aString = [NSString stringWithString: [self uppercaseString]];
	NSRange aRange = {0, [aString length]};

	[aString replaceOccurrencesOfString: @"{" withString: @"[" options: 0
	  range: aRange];
	[aString replaceOccurrencesOfString: @"}" withString: @"]" options: 0
	  range: aRange];
	[aString replaceOccurrencesOfString: @"|" withString: @"\\" options: 0
	  range: aRange];
	[aString replaceOccurrencesOfString: @"^" withString: @"~" options: 0
	  range: aRange];
	
	return [aString uppercaseString];
}
/**
 * Returns a lowercased string (and converts any of []\~ characters found 
 * to {}|^ respectively).
 */
- (NSString *)lowercaseIRCString
{
	NSMutableString *aString = [NSMutableString 
	  stringWithString: [self lowercaseString]];
	NSRange aRange = {0, [aString length]};

	[aString replaceOccurrencesOfString: @"[" withString: @"{" options: 0
	  range: aRange];
	[aString replaceOccurrencesOfString: @"]" withString: @"}" options: 0
	  range: aRange];
	[aString replaceOccurrencesOfString: @"\\" withString: @"|" options: 0
	  range: aRange];
	[aString replaceOccurrencesOfString: @"~" withString: @"^" options: 0
	  range: aRange];
	
	return [aString lowercaseString];
}
/** 
 * Compares this string to <var>aString</var> while taking into account that
 * {}|^ are the lowercase versions of []\~.
 */
- (NSComparisonResult)caseInsensitiveIRCCompare: (NSString *)aString
{
	return [[self uppercaseIRCString] compare:
	   [aString uppercaseIRCString]];
}
@end

@interface IRCObject (InternalIRCObject)
- setErrorString: (NSString *)anError;
@end
	
#define NEXT_SPACE(__y, __z, __string)\
{\
	__z = [(__string) rangeOfCharacterFromSet:\
	[NSCharacterSet whitespaceCharacterSet] options: 0\
	range: NSMakeRange((__y), [(__string) length] - (__y))].location;\
	if (__z == NSNotFound) __z = [(__string) length];\
}
	
#define NEXT_NON_SPACE(__y, __z, __string)\
{\
	int __len = [(__string) length];\
	id set = [NSCharacterSet whitespaceCharacterSet];\
	__z = (__y);\
	while (__z < __len && \
	  [set characterIsMember: [(__string) characterAtIndex: __z]]) __z++;\
}

static inline NSString *get_IRC_prefix(NSString *line, NSString **prefix)
{
	int beg;
	int end;
	int len = [line length];
	
	if (len == 0)
	{
		*prefix = nil;
		return @"";
	}
	NEXT_NON_SPACE(0, beg, line);
	
	if (beg == len)
	{
		*prefix = nil;
		return @"";
	}
	
	NEXT_SPACE(beg, end, line);
		
	if ([line characterAtIndex: beg] != ':')
	{
		*prefix = nil;
		return line;
	}
	else
	{
		beg++;
		if (beg == end)
		{
			*prefix = @"";
			if (beg == len)
			{
				return @"";
			}
			else
			{
				return [line substringFromIndex: beg];
			}
		}
	}
	
	*prefix = [line substringWithRange: NSMakeRange(beg, end - beg)];
	
	if (end != len)
	{
		return [line substringFromIndex: end];
	}
	
	return @"";
}
	
static inline NSString *get_next_IRC_word(NSString *line, NSString **prefix)
{
	int beg;
	int end;
	int len = [line length];
	
	if (len == 0)
	{
		*prefix = nil;
		return @"";
	}
	NEXT_NON_SPACE(0, beg, line);
	
	if (beg == len)
	{
		*prefix = nil;
		return @"";
	}
	if ([line characterAtIndex: beg] == ':')
	{
		beg++;
		if (beg == len)
		{
			*prefix = @"";
		}
		else
		{
			*prefix = [line substringFromIndex: beg];
		}
		
		return @"";
	}
	
   NEXT_SPACE(beg, end, line);
	
	*prefix = [line substringWithRange: NSMakeRange(beg, end - beg)];
	
	if (end != len)
	{
		return [line substringFromIndex: end];
	}
	
	return @"";
}

#undef NEXT_NON_SPACE
#undef NEXT_SPACE

static inline BOOL is_numeric_command(NSString *aString)
{
	static NSCharacterSet *set = nil;
	unichar test[3];
	
	if (!set)
	{
		set = RETAIN([NSCharacterSet 
		  characterSetWithCharactersInString: @"0123456789"]);
	}
	
	if ([aString length] != 3)
	{
		return NO;
	}
	
	[aString getCharacters: test];
	if ([set characterIsMember: test[0]] && [set characterIsMember: test[1]] &&
	    [set characterIsMember: test[2]])
	{
		return YES;
	}
	
	return NO;
}

static inline BOOL contains_a_space(NSString *aString)
{
	return ([aString rangeOfCharacterFromSet: 
	  [NSCharacterSet whitespaceCharacterSet]].location == NSNotFound) ?
	  NO : YES;
}	

static inline NSString *string_to_string(NSString *aString, NSString *delim)
{
	NSRange a = [aString rangeOfString: delim];
	
	if (a.location == NSNotFound) return [NSString stringWithString: aString];
	
	return [aString substringToIndex: a.location];
}

static inline NSString *string_from_string(NSString *aString, NSString *delim)
{
	NSRange a = [aString rangeOfString: delim];
	
	if (a.location == NSNotFound) return nil;
	
	a.location += a.length;
	
	if (a.location == [aString length])
	{
		return @"";
	}
	
	return [aString substringFromIndex: a.location];
}

/**
 * Returns the nickname portion of a prefix.  On any argument after
 * from: in the class reference, the name could be in the format of
 * nickname!host.  Will always return a valid string.
 */
inline NSString *ExtractIRCNick(NSString *prefix)
{	
	if (!prefix) return @"";
	return string_to_string(prefix, @"!");
}

/**
 * Returns the host portion of a prefix.  On any argument after
 * from: in the class reference, the name could be in the format
 * nickname!host.  Returns nil if the prefix is not in the correct
 * format.
 */
inline NSString *ExtractIRCHost(NSString *prefix)
{
	if (!prefix) return @"";
	return string_from_string(prefix, @"!");
}

/**
 * Returns an array of the nickname/host of a prefix.  In the case that
 * the array has only one object, it will be the nickname.  In the case that
 * it has two, it will be [nickname, host].  The object will always be at
 * least one object long and never more than two.
 */
inline NSArray *SeparateIRCNickAndHost(NSString *prefix)
{
	if (!prefix) return [NSArray arrayWithObject: @""];
	return [NSArray arrayWithObjects: string_to_string(prefix, @"!"),
	  string_from_string(prefix, @"!"), nil];
}

static void rec_caction(IRCObject *client, NSString *prefix,
                        NSString *command, NSString *rest, NSString *to)
{
	if ([rest length] == 0)
	{
		return;
	}
	[client actionReceived: rest to: to from: prefix];
}

static void rec_ccustom(IRCObject *client, NSString *prefix, 
                        NSString *command, NSString *rest, NSString *to,
                        NSString *ctcp)
{
	if ([command isEqualToString: @"NOTICE"])
	{
		[client CTCPReplyReceived: ctcp withArgument: rest
		  to: to from: prefix];
	}
	else
	{
		[client CTCPRequestReceived: ctcp withArgument: rest
		  to: to from: prefix];
	}
}

static void rec_nick(IRCObject *client, NSString *command,
                     NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}
		
	if ([paramList count] < 1)
	{
		return;
	}
	
	if ([[client nick] isEqualToString: ExtractIRCNick(prefix)])
	{
		[client setNick: [paramList objectAtIndex: 0]];
	}
	[client nickChangedTo: [paramList objectAtIndex: 0] from: prefix];
}

static void rec_join(IRCObject *client, NSString *command, 
                     NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}

	if ([paramList count] == 0)
	{
		return;
	}

	[client channelJoined: [paramList objectAtIndex: 0] from: prefix];
}

static void rec_part(IRCObject *client, NSString *command,
                     NSString *prefix, NSArray *paramList)
{
	int x;
	
	if (!prefix)
	{	
		return;
	}

	x = [paramList count];
	if (x == 0)
	{
		return;
	}

	[client channelParted: [paramList objectAtIndex: 0] withMessage:
	  (x == 2) ? [paramList objectAtIndex: 1] : 0 from: prefix];
}

static void rec_quit(IRCObject *client, NSString *command,
                     NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}

	if ([paramList count] == 0)
	{
		return;
	}

	[client quitIRCWithMessage: [paramList objectAtIndex: 0] from: prefix];
}

static void rec_topic(IRCObject *client, NSString *command,
                      NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}

	if ([paramList count] < 2)
	{
		return;
	}

	[client topicChangedTo: [paramList objectAtIndex: 1] 
	  in: [paramList objectAtIndex: 0] from: prefix];
}
static void rec_privmsg(IRCObject *client, NSString *command,
                        NSString *prefix, NSArray *paramList)
{
	NSString *message;
	
	if ([paramList count] < 2)
	{
		return;
	}

	message = [paramList objectAtIndex: 1];
	if ([message hasPrefix: @"\001"])
	{
		void (*func)(IRCObject *, NSString *, NSString *, NSString *, 
		              NSString *);
		id ctcp = string_to_string(message, @" ");
		id rest;
		
		if ([ctcp isEqualToString: message])
		{
			if ([ctcp hasSuffix: @"\001"])
			{
				ctcp = [ctcp substringToIndex: [ctcp length] - 1];
			}
			rest = nil;
		}
		else
		{
			NSRange aRange;
			aRange.location = [ctcp length] + 1;
			aRange.length = [message length] - aRange.location;
			
			if ([message hasSuffix: @"\001"])
			{
				aRange.length--;
			}
			
			if (aRange.length > 0)
			{
				rest = [message substringWithRange: aRange];
			}
			else
			{
				rest = nil;
			}
		}	
		func = NSMapGet(ctcp_to_function, ctcp);
		
		if (func)
		{
			func(client, prefix, command, rest, [paramList objectAtIndex: 0]);
		}
		else
		{
			ctcp = [ctcp substringFromIndex: 1];
			rec_ccustom(client, prefix, command, rest,
			  [paramList objectAtIndex: 0], ctcp);
		}
		return;
	}
	
	if ([command isEqualToString: @"PRIVMSG"])
	{
		[client messageReceived: message
		   to: [paramList objectAtIndex: 0] from: prefix];
	}
	else
	{
		[client noticeReceived: message
		   to: [paramList objectAtIndex: 0] from: prefix];
	}
}
static void rec_mode(IRCObject *client, NSString *command, NSString *prefix, 
                     NSArray *paramList)
{
	NSArray *newParams;
	int x;
	
	if (!prefix)
	{
		return;
	}
	
	x = [paramList count];
	if (x < 2)
	{	
		return;
	}

	if (x == 2)
	{
		newParams = AUTORELEASE([NSArray new]);
	}
	else
	{
		NSRange aRange;
		aRange.location = 2;
		aRange.length = x - 2;
		
		newParams = [paramList subarrayWithRange: aRange];
	}
	
	[client modeChanged: [paramList objectAtIndex: 1] 
	  on: [paramList objectAtIndex: 0] withParams: newParams from: prefix];
}
static void rec_invite(IRCObject *client, NSString *command, NSString *prefix, 
                     NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}
	if ([paramList count] < 2)
	{
		return;
	}

	[client invitedTo: [paramList objectAtIndex: 1] from: prefix];
}
static void rec_kick(IRCObject *client, NSString *command, NSString *prefix,
                       NSArray *paramList)
{
	id object;
	
	if (!prefix)
	{
		return;
	}
	if ([paramList count] < 2)
	{
		return;
	}
	
	object = ([paramList count] > 2) ? [paramList objectAtIndex: 2] : nil;
	
	[client userKicked: [paramList objectAtIndex: 1]
	   outOf: [paramList objectAtIndex: 0] for: object from: prefix];
}
static void rec_ping(IRCObject *client, NSString *command, NSString *prefix,
                       NSArray *paramList)
{
	NSString *arg;
	
	arg = [paramList componentsJoinedByString: @" "];
	
	[client pingReceivedWithArgument: arg from: prefix];
}
static void rec_pong(IRCObject *client, NSString *command, NSString *prefix,
                     NSArray *paramList)
{
	NSString *arg;
	
	arg = [paramList componentsJoinedByString: @" "];
	
	[client pongReceivedWithArgument: arg from: prefix];
}
static void rec_wallops(IRCObject *client, NSString *command, NSString *prefix,
                          NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}
	if ([paramList count] < 1)
	{
		return;
	}
	
	[client wallopsReceived: [paramList objectAtIndex: 0] from: prefix];
}
static void rec_error(IRCObject *client, NSString *command, NSString *prefix,
                        NSArray *paramList)
{
	if ([paramList count] < 1)
	{
		return;
	}

	[client errorReceived: [paramList objectAtIndex: 0]];
}


@implementation IRCObject (InternalIRCObject)
- setErrorString: (NSString *)anError
{
	RELEASE(errorString);
	errorString = RETAIN(anError);
	return self;
}
@end

/**
 * <p>
 * IRCObject handles all aspects of an IRC connection.  In almost all
 * cases, you will want to override this class and implement just the
 * callback methods specified in [IRCObject(Callbacks)] to handle 
 * everything.
 * </p>
 * <p>
 * A lot of arguments may not contain spaces.  The general procedure on 
 * processing these arguments is that the method will cut the string
 * off at the first space and use the part of the string before the space
 * and fail only if that string is still invalid.  Try to avoid
 * passing strings with spaces as the arguments to the methods 
 * that warn not to.
 * </p>
 */
@implementation IRCObject
+ (void)initialize
{
	IRC_new_line = [[NSData alloc] initWithBytes: "\r\n" length: 2];

	command_to_function = NSCreateMapTable(NSObjectMapKeyCallBacks,
	   NSIntMapValueCallBacks, 13);
	
	NSMapInsert(command_to_function, @"NICK", rec_nick);
	NSMapInsert(command_to_function, @"JOIN", rec_join);
	NSMapInsert(command_to_function, @"PART", rec_part);
	NSMapInsert(command_to_function, @"QUIT", rec_quit);
	NSMapInsert(command_to_function, @"TOPIC", rec_topic);
	NSMapInsert(command_to_function, @"PRIVMSG", rec_privmsg);
	NSMapInsert(command_to_function, @"NOTICE", rec_privmsg);
	NSMapInsert(command_to_function, @"MODE", rec_mode);
	NSMapInsert(command_to_function, @"KICK", rec_kick);
	NSMapInsert(command_to_function, @"INVITE", rec_invite);
	NSMapInsert(command_to_function, @"PING", rec_ping);
	NSMapInsert(command_to_function, @"PONG", rec_pong);
	NSMapInsert(command_to_function, @"WALLOPS", rec_wallops);
	NSMapInsert(command_to_function, @"ERROR", rec_error);

	ctcp_to_function = NSCreateMapTable(NSObjectMapKeyCallBacks,
	   NSIntMapValueCallBacks, 1);
	
	NSMapInsert(ctcp_to_function, @"\001ACTION", rec_caction);
}
/**
 * <init />
 * Initializes the IRCObject and retains the arguments for the next connection.
 * Uses -setNick:, -setUserName:, -setRealName:, and -setPassword: to save the
 * arguments.
 */
- initWithNickname: (NSString *)aNickname withUserName: (NSString *)aUser
   withRealName: (NSString *)aRealName
   withPassword: (NSString *)aPassword
{
	if (!(self = [super init])) return nil;
	
	defaultEncoding = [NSString defaultCStringEncoding];
	
	if (![self setNick: aNickname])
	{
		[self dealloc];
		return nil;
	}

	if (![self setUserName: aUser])
	{
		[self dealloc];
		return nil;
	}

	if (![self setRealName: aRealName])
	{
		[self dealloc];
		return nil;
	}

	if (![self setPassword: aPassword])
	{
		[self dealloc];
		return nil;
	}

	return self;
}
- (void)dealloc
{
	DESTROY(nick);
	DESTROY(userName);
	DESTROY(realName);
	DESTROY(password);
	DESTROY(errorString);
	
	[super dealloc];
}
- (void)connectionLost
{
	connected = NO;
	[super connectionLost];
}
/**
 * Sets the nickname that this object will attempt to use upon a connection.
 * Do not use this to change the nickname once the object is connected, this
 * is only used when it is actually connecting.  This method returns nil if
 * <var>aNickname</var> is invalid and will set the error string accordingly.
 * <var>aNickname</var> is invalid if it contains a space or is zero-length.
 */
- setNick: (NSString *)aNickname
{
	if (aNickname == nick) return self;
	
	aNickname = string_to_string(aNickname, @" ");
	if ([aNickname length] == 0)
	{
		[self setErrorString: @"No usable nickname provided"];
		return nil;
	}

	RELEASE(nick);
	nick = RETAIN(aNickname);

	return self;
}
/**
 * Returns the nickname that this object will use on connecting next time.
 */
- (NSString *)nick
{
	return nick;
}
/**
 * Sets the user name that this object will give to the server upon the
 * next connection.  If <var>aUser</var> is invalid, it will use the user name
 * of "netclasses".  <var>aUser</var> should not contain spaces.
 * This method will always succeed.
 */
- setUserName: (NSString *)aUser
{
	id enviro;
	
	if ([aUser length] == 0)
	{
		enviro = [[NSProcessInfo processInfo] environment];
		
		aUser = [enviro objectForKey: @"LOGNAME"];

		if ([aUser length] == 0)
		{
			aUser = @"netclasses";
		}
	}
	if ([(aUser = string_to_string(aUser, @" ")) length] == 0)
	{
		aUser = @"netclasses";
	}

	RELEASE(userName);
	userName = RETAIN(aUser);
	
	return self;
}
/**
 * Returns the user name that will be used upon the next connection.
 */
- (NSString *)userName
{
	return userName;
}
/**
 * Sets the real name that will be passed to the IRC server on the next
 * connection.  If <var>aRealName</var> is nil or zero-length, the name
 * "John Doe" shall be used.  This method will always succeed.
 */
- setRealName: (NSString *)aRealName
{
	if ([aRealName length] == 0)
	{
		aRealName = @"John Doe";
	}

	RELEASE(realName);
	realName = RETAIN(aRealName);

	return self;
}
/**
 * Returns the real name that will be used upon the next connection.
 */
- (NSString *)realName
{
	return realName;
}
/**
 * Sets the password that will be used upon connecting to the IRC server.
 * <var>aPass</var> can be nil or zero-length, in which case no password
 * shall be used. <var>aPass</var> may not contain a space.  Will return 
 * nil and set the error string if this fails. 
 */
- setPassword: (NSString *)aPass
{
	if ([aPass length])
	{
		if ([(aPass = string_to_string(aPass, @" ")) length] == 0) 
		{
			[self setErrorString: @"Unusable password"];
			return nil;
		}
	}
	else
	{
		aPass = nil;
	}
	
	DESTROY(password);
	password = RETAIN(aPass);
	
	return self;
}
/** 
 * Returns the password that will be used upon the next connection to a 
 * IRC server.
 */
- (NSString *)password
{
	return password;
}
/**
 * Returns a string that describes the last error that happened.
 */
- (NSString *)errorString
{
	return errorString;
}
- connectionEstablished: aTransport
{
	[super connectionEstablished: aTransport];
	
	if (password)
	{
		[self writeString: [NSString stringWithFormat: 
		  @"PASS %@", password]];
	}

	[self changeNick: nick];

	[self writeString: @"USER %@ %@ %@ :%@", userName, @"localhost", 
	  @"netclasses", realName];
	return self;
}
/** 
 * Returns YES when the IRC object is fully connected and registered with
 * the IRC server.  Returns NO if the connection has not made or this 
 * connection has not fully registered with the server.
 */
- (BOOL)connected
{
	return connected;
}
/**
 * Sets the encoding that will be used for incoming as well as outgoing
 * messages.  <var>aEncoding</var> should be an 8-bit encoding for a typical
 * IRC server.  Uses the system default by default.
 */
- setEncoding: (NSStringEncoding)aEncoding
{
	defaultEncoding = aEncoding;
	return self;
}
/**
 * Returns the encoding currently being used by the connection.
 */
- (NSStringEncoding)encoding
{
	return defaultEncoding;
}
/**
 * Sets the nickname to the <var>aNick</var>.  This method is quite similar
 * to -setNick: but this will also actually send the nick change request to
 * the server if connected, and will only affect the nickname stored by the 
 * object (which is returned with -nick) if the the name change was successful
 * or the object is not yet registered/connected.  Please see RFC 1459 for
 * more information on the NICK command.
 */
- changeNick: (NSString *)aNick
{
	if ([aNick length] > 0)
	{
		if ([(aNick = string_to_string(aNick, @" ")) length] == 0)
		{
			[NSException raise: IRCException
			 format: @"[IRCObject changeNick: '%@'] Unusable nickname given",
			  aNick];
		}
		if (!connected)
		{
			[self setNick: aNick];
		}

		[self writeString: @"NICK %@", aNick];
	}
	return self;
}
/** 
 * Quits IRC with an optional message.  <var>aMessage</var> can have 
 * spaces.  If <var>aMessage</var> is nil or zero-length, the server
 * will often provide its own message.  Please see RFC 1459 for more
 * information on the QUIT command.
 */
- quitWithMessage: (NSString *)aMessage
{
	if ([aMessage length] > 0)
	{
		[self writeString: @"QUIT :%@", aMessage];
	}
	else
	{
		[self writeString: @"QUIT"];
	}
	return self;
}
/**
 * Leaves the channel <var>aChannel</var> with the optional message
 * <var>aMessage</var>.  <var>aMessage</var> may contain spaces, and
 * <var>aChannel</var> may not.  <var>aChannel</var> may also be a 
 * comma separated list of channels.  Please see RFC 1459 for more 
 * information on the PART command.
 */
- partChannel: (NSString *)aChannel withMessage: (NSString *)aMessage
{
	if ([aChannel length] == 0)
	{
		return self;
	}
	
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject partChannel: '%@' ...] Unusable channel given",
		  aChannel];
	}
	
	if ([aMessage length] > 0)
	{
		[self writeString: @"PART %@ :%@", aChannel, aMessage];
	}
	else
	{
		[self writeString: @"PART %@", aChannel];
	}
	
	return self;
}
/**
 * Joins the channel <var>aChannel</var> with an optional password of
 * <var>aPassword</var>.  Neither may contain spaces, and both may be
 * comma separated for multiple channels/passwords.  If there is one
 * or more passwords, it should match the number of channels specified
 * by <var>aChannel</var>.  Please see RFC 1459 for more information on
 * the JOIN command.
 */
- joinChannel: (NSString *)aChannel withPassword: (NSString *)aPassword
{
	if ([aChannel length] == 0)
	{
		return self;
	}

	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject joinChannel: '%@' ...] Unusable channel",
		  aChannel];
	}

	if ([aPassword length] == 0)
	{
		[self writeString: @"JOIN %@", aChannel];
		return self;
	}

	if ([(aPassword = string_to_string(aPassword, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject joinChannel: withPassword: '%@'] Unusable password",
		  aPassword];
	}

	[self writeString: @"JOIN %@ %@", aChannel, aPassword];

	return self;
}
/**
 * Sends a CTCP <var>aCTCP</var> reply to <var>aPerson</var> with the 
 * argument <var>args</var>.  <var>args</var> may contain spaces and is
 * optional while the rest may not.  This method should be used to 
 * respond to a CTCP message sent by another client. See
 * -sendCTCPRequest:withArgument:to:
 */
- sendCTCPReply: (NSString *)aCTCP withArgument: (NSString *)args
   to: (NSString *)aPerson
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		  @"[IRCObject sendCTCPReply: '%@'withArgument: '%@' to: '%@'] Unusable receiver",
		    aCTCP, args, aPerson];
	}
	if (!aCTCP)
	{
		aCTCP = @"";
	}
	if ([args length])
	{
		[self writeString: @"NOTICE %@ :\001%@ %@\001", aPerson, aCTCP, args];
	}
	else
	{
		[self writeString: @"NOTICE %@ :\001%@\001", aPerson, aCTCP];
	}
		
	return self;
}
/**
 * Sends a CTCP <var>aCTCP</var> request to <var>aPerson</var> with an
 * optional argument <var>args</var>.  <var>args</var> may contain a space
 * while the rest may not.  This should be used to request CTCP information
 * from another client and never for responding.  See 
 * -sendCTCPReply:withArgument:to:
 */
- sendCTCPRequest: (NSString *)aCTCP withArgument: (NSString *)args
   to: (NSString *)aPerson
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		  @"[IRCObject sendCTCPRequest: '%@'withArgument: '%@' to: '%@'] Unusable receiver",
		    aCTCP, args, aPerson];
	}
	if (!aCTCP)
	{
		aCTCP = @"";
	}
	if ([args length])
	{
		[self writeString: @"PRIVMSG %@ :\001%@ %@\001", aPerson, aCTCP, args];
	}
	else
	{
		[self writeString: @"PRIVMSG %@ :\001%@\001", aPerson, aCTCP];
	}
		
	return self;
}
/**
 * Sends a message <var>aMessage</var> to <var>aReceiver</var>.
 * <var>aReceiver</var> may be a nickname or a channel name.  
 * <var>aMessage</var> may contain spaces.  This is used to carry 
 * out the basic communication over IRC.  Please see RFC 1459 for more
 * information on the PRIVMSG message.
 */
- sendMessage: (NSString *)aMessage to: (NSString *)aReceiver
{
	if ([aMessage length] == 0)
	{
		return self;
	}
	if ([aReceiver length] == 0)
	{
		return self;
	}
	if ([(aReceiver = string_to_string(aReceiver, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject sendMessage: '%@' to: '%@'] Unusable receiver",
		  aMessage, aReceiver];
	}
	
	[self writeString: @"PRIVMSG %@ :%@", aReceiver, aMessage];
	
	return self;
}
/**
 * Sends a notice <var>aNotice</var> to <var>aReceiver</var>.  
 * <var>aReceiver</var> may not contain a space.  This is generally
 * not used except for system messages and should rarely be used by
 * a regular client.  Please see RFC 1459 for more information on the
 * NOTICE command.
 */
- sendNotice: (NSString *)aNotice to: (NSString *)aReceiver
{
	if ([aNotice length] == 0)
	{
		return self;
	}
	if ([aReceiver length] == 0)
	{
		return self;
	}
	if ([(aReceiver = string_to_string(aReceiver, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject sendNotice: '%@' to: '%@'] Unusable receiver",
		  aNotice, aReceiver];
	}
	
	[self writeString: @"NOTICE %@ :%@", aReceiver, aNotice];
	
	return self;
}
/**
 * Sends an action <var>anAction</var> to the receiver <var>aReceiver</var>.
 * This is similar to a message but will often be displayed such as:<br /><br />
 * &lt;nick&gt; &lt;anAction&gt;<br /><br /> and can be used effectively to display things
 * that you are <em>doing</em> rather than saying.  <var>anAction</var>
 * may contain spaces.
 */
- sendAction: (NSString *)anAction to: (NSString *)aReceiver
{
	if ([anAction length] == 0)
	{
		return self;
	}
	if ([aReceiver length] == 0)
	{
		return self;
	}
	if ([(aReceiver = string_to_string(aReceiver, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject sendAction: '%@' to: '%@'] Unusable receiver",
		   anAction, aReceiver];
	}

	[self writeString: @"PRIVMSG %@ :\001ACTION %@\001", aReceiver, anAction];
	
	return self;
}
/**
 * This method attempts to become an IRC operator with name <var>aName</var>
 * and password <var>aPassword</var>.  Neither may contain spaces.  This is
 * a totally different concept than channel operators since it refers to 
 * operators of the server as a whole.  Please see RFC 1459 for more information
 * on the OPER command.
 */
- becomeOperatorWithName: (NSString *)aName withPassword: (NSString *)aPassword
{
	if (([aName length] == 0) || ([aPassword length] == 0))
	{
		return self;
	}
	if ([(aPassword = string_to_string(aPassword, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject becomeOperatorWithName: %@ withPassword: %@] Unusable password",
		  aName, aPassword];
	}
	if ([(aName = string_to_string(aName, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject becomeOperatorWithName: %@ withPassword: %@] Unusable name",
		  aName, aPassword];
	}
	
	[self writeString: @"OPER %@ %@", aName, aPassword];
	
	return self;
}
/**
 * Requests the names on a channel <var>aChannel</var>.  If <var>aChannel</var>
 * is not specified, all users in all channels will be returned.  The information
 * will be returned via a <var>RPL_NAMREPLY</var> numeric message.  See the
 * RFC 1459 for more information on the NAMES command.
 */
- requestNamesOnChannel: (NSString *)aChannel
{
	if ([aChannel length] == 0)
	{
		[self writeString: @"NAMES"];
		return self;
	}
	
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: 
		  @"[IRCObject requestNamesOnChannel: %@] Unusable channel",
		   aChannel];
	}
			
	[self writeString: @"NAMES %@", aChannel];

	return self;
}
/**
 * Requests the Message-Of-The-Day from server <var>aServer</var>.  <var>aServer</var>
 * is optional and may not contain spaces if present.  The message of the day
 * is returned through the <var>RPL_MOTD</var> numeric command.
 */
- requestMOTDOnServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"MOTD"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format: 
		  @"[IRCObject requestMOTDOnServer:'%@'] Unusable server",
		  aServer];
	}

	[self writeString: @"MOTD %@", aServer];
	return self;
}
/**
 * Requests size information from an optional <var>aServer</var> and
 * optionally forwards it to <var>anotherServer</var>.  See RFC 1459 for
 * more information on the LUSERS command
 */
- requestSizeInformationFromServer: (NSString *)aServer 
    andForwardTo: (NSString *)anotherServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"LUSERS"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestSizeInformationFromServer: '%@' andForwardTo: '%@'] Unusable first server", 
		  aServer, anotherServer];
	}
	if ([anotherServer length] == 0)
	{
		[self writeString: @"LUSERS %@", aServer];
		return self;
	}
	if ([(anotherServer = string_to_string(anotherServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestSizeInformationFromServer: '%@' andForwardTo: '%@'] Unusable second server",
		 aServer, anotherServer];
	}

	[self writeString: @"LUSERS %@ %@", aServer, anotherServer];
	return self;
}	
/**
 * Queries the version of optional <var>aServer</var>.  Please see 
 * RFC 1459 for more information on the VERSION command.
 */
- requestVersionOfServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"VERSION"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestVersionOfServer: '%@'] Unusable server",
		  aServer];
	}

	[self writeString: @"VERSION %@", aServer];
	return self;
}
/**
 * Returns a series of statistics from <var>aServer</var>.  Specific 
 * queries can be made with the optional <var>query</var> argument.  
 * Neither may contain spaces and both are optional.  See RFC 1459 for
 * more information on the STATS message
 */
- requestServerStats: (NSString *)aServer for: (NSString *)query
{
	if ([query length] == 0)
	{
		[self writeString: @"STATS"];
		return self;
	}
	if ([(query = string_to_string(query, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestServerStats: '%@' for: '%@'] Unusable query",
		  aServer, query];
	}
	if ([aServer length] == 0)
	{
		[self writeString: @"STATS %@", query];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestServerStats: '%@' for: '%@'] Unusable server",
		  aServer, query];
	}
	
	[self writeString: @"STATS %@ %@", query, aServer];
	return self;
}
/** 
 * Used to list servers connected to optional <var>aServer</var> with
 * an optional mask <var>aLink</var>.  Neither may contain spaces.
 * See the RFC 1459 for more information on the LINKS command.
 */
- requestServerLink: (NSString *)aLink from: (NSString *)aServer
{
	if ([aLink length] == 0)
	{
		[self writeString: @"LINKS"];
		return self;
	}
	if ([(aLink = string_to_string(aLink, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestServerLink: '%@' from: '%@'] Unusable link",
		  aLink, aServer];
	}
	if ([aServer length] == 0)
	{
		[self writeString: @"LINKS %@", aLink];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestServerLink: '%@' from: '%@'] Unusable server", 
		  aLink, aServer];
	}

	[self writeString: @"LINKS %@ %@", aServer, aLink];
	return self;
}
/**
 * Requests the local time from the optional server <var>aServer</var>.  
 * <var>aServer</var> may not contain spaces.  See RFC 1459 for more 
 * information on the TIME command.
 */
- requestTimeOnServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"TIME"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestTimeOnServer: '%@'] Unusable server",
		  aServer];
	}

	[self writeString: @"TIME %@", aServer];
	return self;
}
/**
 * Requests that <var>aServer</var> connects to <var>connectServer</var> on
 * port <var>aPort</var>.  <var>aServer</var> and <var>aPort</var> are optional
 * and none may contain spaces.  See RFC 1459 for more information on the 
 * CONNECT command.
 */
- requestServerToConnect: (NSString *)aServer to: (NSString *)connectServer
                  onPort: (NSString *)aPort
{
	if ([connectServer length] == 0)
	{
		return self;
	}
	if ([(connectServer = string_to_string(connectServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestServerToConnect: '%@' to: '%@' onPort: '%@'] Unusable second server",
		  aServer, connectServer, aPort];
	}
	if ([aPort length] == 0)
	{
		return self;
	}
	if ([(aPort = string_to_string(aPort, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestServerToConnect: '%@' to: '%@' onPort: '%@'] Unusable port",
		  aServer, connectServer, aPort];
	}
	if ([aServer length] == 0)
	{
		[self writeString: @"CONNECT %@ %@", connectServer, aPort];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format: 
		 @"[IRCObject requestServerToConnect: '%@' to: '%@' onPort: '%@'] Unusable first server",
		  aServer, connectServer, aPort];
	}
	
	[self writeString: @"CONNECT %@ %@ %@", connectServer, aPort, aServer];
	return self;
}
/**
 * This message will request the route to a specific server from a client.
 * <var>aServer</var> is optional and may not contain spaces; please see
 * RFC 1459 for more information on the TRACE command.
 */
- requestTraceOnServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"TRACE"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format: 
		 @"[IRCObject requestTraceOnServer: '%@'] Unusable server",
		  aServer];
	}
	
	[self writeString: @"TRACE %@", aServer];
	return self;
}
/**
 * Request the name of the administrator on the optional server
 * <var>aServer</var>.  <var>aServer</var> may not contain spaces.  Please
 * see RFC 1459 for more information on the ADMIN command.
 */
- requestAdministratorOnServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"ADMIN"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestAdministratorOnServer: '%@'] Unusable server", 
		  aServer];
	}

	[self writeString: @"ADMIN %@", aServer];
	return self;
}
/**
 * Requests information on a server <var>aServer</var>.  <var>aServer</var>
 * is optional and may not contain spaces.  Please see RFC 1459 for more 
 * information on the INFO command.
 */
- requestInfoOnServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"INFO"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestInfoOnServer: '%@'] Unusable server",
		  aServer];
	}

	[self writeString: @"INFO %@", aServer];
	return self;
}
/**
 * Used to request that the current server reread its configuration files.
 * Please see RFC 1459 for more information on the REHASH command.
 */
- requestServerRehash
{
	[self writeString: @"REHASH"];
	return self;
}
/**
 * Used to request a shutdown of a server.  Please see RFC 1459 for additional
 * information on the DIE command.
 */
- requestServerShutdown
{
	[self writeString: @"DIE"];
	return self;
}
/**
 * Requests a restart of a server.  Please see RFC 1459 for additional 
 * information on the RESTART command.
 */
- requestServerRestart
{
	[self writeString: @"RESTART"];
	return self;
}
/** 
 * Requests a list of users logged into <var>aServer</var>.  
 * <var>aServer</var> is optional and may contain spaces.  Please see 
 * RFC 1459 for additional information on the USERS message.
 */
- requestUserInfoOnServer: (NSString *)aServer
{
	if ([aServer length] == 0)
	{
		[self writeString: @"USERS"];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject requestUserInfoOnServer: '%@'] Unusable server",
		  aServer];
	}

	[self writeString: @"USERS %@", aServer];
	return self;
}
/**
 * Requests information on the precense of certain nicknames listed in 
 * <var>userList</var> on the network.  <var>userList</var> is a space 
 * separated list of users.  For each user that is present, its name will
 * be added to the reply through the numeric message <var>RPL_ISON</var>.
 * See RFC 1459 for more information on the ISON message.
 */
- areUsersOn: (NSString *)userList
{
	if ([userList length] == 0)
	{
		return self;
	}
	
	[self writeString: @"ISON %@", userList];
	return self;
}
/**
 * Sends a message to all operators currently online.  The actual implementation
 * may vary from server to server in regards to who can send and receive it.
 * <var>aMessage</var> is the message to be sent and may contain spaces. 
 * Please see RFC 1459 for more information regarding the WALLOPS command.
 */
- sendWallops: (NSString *)aMessage
{
	if ([aMessage length] == 0)
	{
		return self;
	}

	[self writeString: @"WALLOPS :%@", aMessage];
	return self;
}
/**
 * Requests a list of users with a matching mask <var>aMask</var> against 
 * their username and/or host.  This can optionally be done just against 
 * the IRC operators. The mask <var>aMask</var> is optional and may not 
 * contain spaces.  Please see RFC 1459 for more information regarding the
 * WHO message.
 */
- listWho: (NSString *)aMask onlyOperators: (BOOL)operators
{
	if ([aMask length] == 0)
	{
		[self writeString: @"WHO"];
		return self;
	}
	if ([(aMask = string_to_string(aMask, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject listWho: '%@' onlyOperators: %d] Unusable mask",
		 aMask, operators];
	}
	
	if (operators)
	{
		[self writeString: @"WHO %@ o", aMask];
	}
	else
	{
		[self writeString: @"WHO %@", aMask];
	}
	
	return self;
}
/**
 * Requests information on a user <var>aPerson</var>.  <var>aPerson</var>
 * may also be a comma separated list for additional users.  <var>aServer</var>
 * is optional and neither argument may contain spaces.  Refer to RFC 1459 for
 * additional information on the WHOIS command.
 */
- whois: (NSString *)aPerson onServer: (NSString *)aServer
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject whois: '%@' onServer: '%@'] Unusable person",
		 aPerson, aServer];
	}
	if ([aServer length] == 0)
	{
		[self writeString: @"WHOIS %@", aPerson];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject whois: '%@' onServer: '%@'] Unusable server",
		  aPerson, aServer];
	}

	[self writeString: @"WHOIS %@ %@", aServer, aPerson];
	return self;
}
/** 
 * Requests information on a user <var>aPerson</var> that is no longer 
 * connected to the server <var>aServer</var>.  A possible maximum number
 * of entries <var>aNumber</var> may be displayed.  All arguments may not
 * contain spaces and <var>aServer</var> and <var>aNumber</var> are optional.
 * Please refer to RFC 1459 for more information regarding the WHOWAS message.
 */
- whowas: (NSString *)aPerson onServer: (NSString *)aServer
      withNumberEntries: (NSString *)aNumber
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject whowas: '%@' onServer: '%@' withNumberEntries: '%@'] Unusable person",
		  aPerson, aServer, aNumber];
	}
	if ([aNumber length] == 0)
	{
		[self writeString: @"WHOWAS %@", aPerson];
		return self;
	}
	if ([(aNumber = string_to_string(aNumber, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject whowas: '%@' onServer: '%@' withNumberEntries: '%@'] Unusable number of entries", 
		  aPerson, aServer, aNumber];
	}
	if ([aServer length] == 0)
	{
		[self writeString: @"WHOWAS %@ %@", aPerson, aNumber];
		return self;
	}
	if ([(aServer = string_to_string(aServer, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject whowas: '%@' onServer: '%@' withNumberEntries: '%@'] Unusable server",
		  aPerson, aServer, aNumber];
	}

	[self writeString: @"WHOWAS %@ %@ %@", aPerson, aNumber, aServer];
	return self;
}
/**
 * Used to kill the connection to <var>aPerson</var> with a possible comment
 * <var>aComment</var>.  This is often used by servers when duplicate nicknames
 * are found and may be available to the IRC operators.  <var>aComment</var>
 * is optional and <var>aPerson</var> may not contain spaces.  Please see 
 * RFC 1459 for additional information on the KILL command.
 */
- kill: (NSString *)aPerson withComment: (NSString *)aComment
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject kill: '%@' withComment: '%@'] Unusable person",
		 aPerson, aComment];
	}
	if ([aComment length] == 0)
	{
		return self;
	}

	[self writeString: @"KILL %@ :%@", aPerson, aComment];
	return self;
}
/**
 * Sets the topic for channel <var>aChannel</var> to <var>aTopic</var>.
 * If the <var>aTopic</var> is omitted, the topic for <var>aChannel</var>
 * will be returned through the <var>RPL_TOPIC</var> numeric message.  
 * <var>aChannel</var> may not contain spaces.  Please refer to the 
 * TOPIC command in RFC 1459 for more information.
 */
- setTopicForChannel: (NSString *)aChannel to: (NSString *)aTopic
{
	if ([aChannel length] == 0)
	{
		return self;
	}
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject setTopicForChannel: %@ to: %@] Unusable channel",
		   aChannel, aTopic];
	}

	if ([aTopic length] == 0)
	{
		[self writeString: @"TOPIC %@", aChannel];
	}
	else
	{
		[self writeString: @"TOPIC %@ :%@", aChannel, aTopic];
	}

	return self;
}
/** 
 * Used to query or set the mode on <var>anObject</var> to the mode specified
 * by <var>aMode</var>.  Flags can be added by adding a '+' to the <var>aMode</var>
 * string or removed by adding a '-' to the <var>aMode</var> string.  These flags
 * may optionally have arguments specified in <var>aList</var> and may be applied
 * to the object specified by <var>anObject</var>.  Examples:
 * <example>
 * aMode: @"+i" anObject: @"#gnustep" withParams: nil
 *   sets the channel "#gnustep" to invite only.
 * aMode: @"+o" anObject: @"#gnustep" withParams: (@"aeruder")
 *   makes aeruder a channel operator of #gnustep
 * </example>
 * Many servers have differing implementations of these modes and may have various
 * modes available to users.  None of the arguments may contain spaces.  Please
 * refer to RFC 1459 for additional information on the MODE message.
 */
- setMode: (NSString *)aMode on: (NSString *)anObject 
                     withParams: (NSArray *)aList
{
	NSMutableString *aString;
	NSEnumerator *iter;
	id object;
	
	if ([anObject length] == 0)
	{
		return self;
	}
	if ([(anObject = string_to_string(anObject, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		  @"[IRCObject setMode:'%@' on:'%@' withParams:'%@'] Unusable object", 
		    aMode, anObject, aList];
	}
	if ([aMode length] == 0)
	{
		[self writeString: @"MODE %@", anObject];
		return self;
	}
	if ([(aMode = string_to_string(aMode, @" ")) length] == 0)
	{		
		[NSException raise: IRCException format:
		  @"[IRCObject setMode:'%@' on:'%@' withParams:'%@'] Unusable mode", 
		    aMode, anObject, aList];
	}
	if (!aList)
	{
		[self writeString: @"MODE %@ %@", anObject, aMode];
		return self;
	}
	
	aString = [NSMutableString stringWithFormat: @"MODE %@ %@", 
	            anObject, aMode];
				
	iter = [aList objectEnumerator];
	
	while ((object = [iter nextObject]))
	{
		[aString appendString: @" "];
		[aString appendString: object];
	}
	
	[self writeString: @"%@", aString];

	return self;
}
/**
 * Lists channel information about the channel specified by <var>aChannel</var>
 * on the server <var>aServer</var>.  <var>aChannel</var> may be a comma separated
 * list and may not contain spaces.  <var>aServer</var> is optional.  If <var>aChannel</var>
 * is omitted, then all channels on the server will be listed.  Please refer
 * to RFC 1459 for additional information on the LIST command.
 */
- listChannel: (NSString *)aChannel onServer: (NSString *)aServer
{
	if ([aChannel length] == 0)
	{
		[self writeString: @"LIST"];
		return self;
	}
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject listChannel:'%@' onServer:'%@'] Unusable channel",
		  aChannel, aServer];
	}
	if ([aServer length] == 0)
	{
		[self writeString: @"LIST %@", aChannel];
		return self;
	}
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject listChannel:'%@' onServer:'%@'] Unusable server",
		  aChannel, aServer];
	}
	
	[self writeString: @"LIST %@ %@", aChannel, aServer];
	return self;
}
/**
 * This message will invite <var>aPerson</var> to the channel specified by
 * <var>aChannel</var>.  Neither may contain spaces and both are required.
 * Please refer to RFC 1459 concerning the INVITE command for additional 
 * information.
 */
- invite: (NSString *)aPerson to: (NSString *)aChannel
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([aChannel length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject invite:'%@' to:'%@'] Unusable person",
		  aPerson, aChannel];
	}
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject invite:'%@' to:'%@'] Unusable channel",
		  aPerson, aChannel];
	}
	
	[self writeString: @"INVITE %@ %@", aPerson, aChannel];
	return self;
}
/**
 * Kicks the user <var>aPerson</var> off of the channel <var>aChannel</var>
 * for the reason specified in <var>aReason</var>.  <var>aReason</var> may 
 * contain spaces and is optional.  If omitted the server will most likely
 * supply a default message.  <var>aPerson</var> and <var>aChannel</var> 
 * are required and may not contain spaces.  Please see the KICK command for
 * additional information in RFC 1459.
 */
- kick: (NSString *)aPerson offOf: (NSString *)aChannel for: (NSString *)aReason
{
	if ([aPerson length] == 0)
	{
		return self;
	}
	if ([aChannel length] == 0)
	{
		return self;
	}
	if ([(aPerson = string_to_string(aPerson, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject kick:'%@' offOf:'%@' for:'%@'] Unusable person",
		  aPerson, aChannel, aReason];
	}
	if ([(aChannel = string_to_string(aChannel, @" ")) length] == 0)
	{
		[NSException raise: IRCException format:
		 @"[IRCObject kick:'%@' offOf:'%@' for:'%@'] Unusable channel",
		  aPerson, aChannel, aReason];
	}
	if ([aReason length] == 0)
	{
		[self writeString: @"KICK %@ %@", aChannel, aPerson];
		return self;
	}

	[self writeString: @"KICK %@ %@ :%@", aChannel, aPerson, aReason];
	return self;
}
/**
 * Sets status to away with the message <var>aMessage</var>.  While away, if
 * a user should send you a message, <var>aMessage</var> will be returned to
 * them to explain your absence.  <var>aMessage</var> may contain spaces.  If
 * omitted, the user is marked as being present.  Please refer to the AWAY 
 * command in RFC 1459 for additional information.
 */
- setAwayWithMessage: (NSString *)aMessage
{
	if ([aMessage length] == 0)
	{
		[self writeString: @"AWAY"];
		return self;
	}

	[self writeString: @"AWAY :%@", aMessage];
	return self;
}
/**
 * Requests a PONG message from the server.  The argument <var>aString</var>
 * is essential but may contain spaces.  The server will respond immediately
 * with a PONG message with the same argument.  This commnd is rarely needed
 * by a client, but is sent out often by servers to ensure connectivity of 
 * clients.  Please see RFC 1459 for more information on the PING command.
 */
- sendPingWithArgument: (NSString *)aString
{
	if (!aString)
	{
		aString = @"";
	}

	[self writeString: @"PING :%@", aString];
	
	return self;
}
/**
 * Used to respond to a PING message.  The argument sent with the PING message
 * should be the argument specified by <var>aString</var>.  <var>aString</var>
 * is required and may contain spaces.  See RFC 1459 for more informtion
 * regarding the PONG command.
 */
- sendPongWithArgument: (NSString *)aString
{
	if (!aString)
	{
		aString = @"";
	}

	[self writeString: @"PONG :%@", aString];
	
	return self;
}
@end

/**
 * This category represents all the callback methods in IRCObject.  You can
 * override these with a subclass.  All of them do not do anything especially
 * important by default, so feel free to not call the default implementation.
 * 
 * On any method ending with an argument like 'from: (NSString *)aString',
 * <var>aString</var> could be in the format of nickname!host.  Please see
 * the documentation for ExtractIRCNick(), ExtractIRCHost(), and 
 * SeparateIRCNickAndHost() for more information.
 */
@implementation IRCObject (Callbacks)
/**
 * This method will be called when the connection is fully registered with
 * the server.  At this point it is safe to start joining channels and carrying
 * out other typical IRC functions. 
 */
- registeredWithServer
{
	return self;
}
/**
 * This method will be called if a connection cannot register for whatever reason.
 * This reason will be outlined in <var>aReason</var>, but the best way to track
 * the reason is to watch the numeric commands being received in the 
 * -numericCommandReceived:withParams:from: method.
 */
- couldNotRegister: (NSString *)aReason
{
	return self;
}	
/**
 * Called when a CTCP request has been received.  The CTCP request type is
 * stored in <var>aCTCP</var>(could be such things as DCC, PING, VERSION, etc.)
 * and the argument is stored in <var>anArgument</var>.  The actual location
 * that the CTCP request is sent is stored in <var>aReceiver</var> and the 
 * person who sent it is stored in <var>aPerson</var>.
 */
- CTCPRequestReceived: (NSString *)aCTCP
   withArgument: (NSString *)anArgument to: (NSString *)aReceiver
   from: (NSString *)aPerson
{
	return self;
}
/**
 * Called when a CTCP reply has been received.  The CTCP reply type is
 * stored in <var>aCTCP</var> with its argument in <var>anArgument</var>.
 * The actual location that the CTCP reply was sent is stored in <var>aReceiver</var>
 * and the person who sent it is stored in <var>aPerson</var>.
 */
- CTCPReplyReceived: (NSString *)aCTCP
   withArgument: (NSString *)anArgument to: (NSString *)aReceiver
   from: (NSString *)aPerson
{
	return self;
}
/**
 * Called when an IRC error has occurred.  This is a message sent by the server
 * and its argument is stored in <var>anError</var>.  Typically you will be 
 * disconnected after receiving one of these.
 */
- errorReceived: (NSString *)anError
{
	return self;
}
/**
 * Called when a Wallops has been received.  The message is stored in 
 * <var>aMessage</var> and the person who sent it is stored in 
 * <var>aSender</var>.
 */
- wallopsReceived: (NSString *)aMessage from: (NSString *)aSender
{
	return self;
}
/**
 * Called when a user has been kicked out of a channel.  The person's nickname
 * is stored in <var>aPerson</var> and the channel he/she was kicked out of is
 * in <var>aChannel</var>.  <var>aReason</var> is the kicker-supplied reason for
 * the removal.  <var>aKicker</var> is the person who did the kicking.  This will
 * not be accompanied by a -channelParted:withMessage:from: message, so it is safe
 * to assume they are no longer part of the channel after receiving this method.
 */
- userKicked: (NSString *)aPerson outOf: (NSString *)aChannel 
         for: (NSString *)aReason from: (NSString *)aKicker
{
	return self;
}
/**
 * Called when the client has been invited to another channel <var>aChannel</var>
 * by <var>anInviter</var>.
 */
- invitedTo: (NSString *)aChannel from: (NSString *)anInviter
{
	return self;
}
/**
 * Called when the mode has been changed on <var>anObject</var>.  The actual
 * mode change is stored in <var>aMode</var> and the parameters are stored in
 * <var>paramList</var>.  The person who changed the mode is stored in 
 * <var>aPerson</var>.  Consult RFC 1459 for further information.
 */
- modeChanged: (NSString *)aMode on: (NSString *)anObject 
    withParams: (NSArray *)paramList from: (NSString *)aPerson
{
	return self;
}
/**
 * Called when a numeric command has been received.  These are 3 digit numerical
 * messages stored in <var>aCommand</var> with a number of parameters stored
 * in <var>paramList</var>.  The sender, almost always the server, is stored
 * in <var>aSender</var>.  These are often used for replies to requests such
 * as user lists and channel lists and other times they are used for errors.
 */
- numericCommandReceived: (NSString *)aCommand withParams: (NSArray *)paramList 
    from: (NSString *)aSender
{
	return self;
}
/**
 * Called when someone changes his/her nickname.  The new nickname is stored in
 * <var>newName</var> and the old name will be stored in <var>aPerson</var>.
 */
- nickChangedTo: (NSString *)newName from: (NSString *)aPerson
{
	return self;
}
/**
 * Called when someone joins a channel.  The channel is stored in <var>aChannel</var>
 * and the person who joined is stored in <var>aJoiner</var>.
 */
- channelJoined: (NSString *)aChannel from: (NSString *)aJoiner
{
	return self;
}
/**
 * Called when someone leaves a channel.  The channel is stored in <var>aChannel</var>
 * and the person who left is stored in <var>aParter</var>.  The parting message will
 * be stored in <var>aMessage</var>.
 */
- channelParted: (NSString *)aChannel withMessage: (NSString *)aMessage
             from: (NSString *)aParter
{
	return self;
}
/**
 * Called when someone quits IRC.  Their parting message will be stored in
 * <var>aMessage</var> and the person who quit will be stored in 
 * <var>aQuitter</var>.
 */
- quitIRCWithMessage: (NSString *)aMessage from: (NSString *)aQuitter
{
	return self;
}
/**
 * Called when the topic is changed in a channel <var>aChannel</var> to
 * <var>aTopic</var> by <var>aPerson</var>.
 */
- topicChangedTo: (NSString *)aTopic in: (NSString *)aChannel
              from: (NSString *)aPerson
{
	return self;
}
/**
 * Called when a message <var>aMessage</var> is received from <var>aSender</var>.
 * The person or channel that the message is addressed to is stored in <var>aReceiver</var>.
 */
- messageReceived: (NSString *)aMessage to: (NSString *)aReceiver
               from: (NSString *)aSender
{
	return self;
}
/**
 * Called when a notice <var>aNotice</var> is received from <var>aSender</var>.
 * The person or channel that the notice is addressed to is stored in <var>aReceiver</var>.
 */
- noticeReceived: (NSString *)aNotice to: (NSString *)aReceiver
              from: (NSString *)aSender
{
	return self;
}
/**
 * Called when an action has been received.  The action is stored in <var>anAction</var>
 * and the sender is stored in <var>aSender</var>.  The person or channel that
 * the action is addressed to is stored in <var>aReceiver</var>.
 */
- actionReceived: (NSString *)anAction to: (NSString *)aReceiver
              from: (NSString *)aSender
{
	return self;
}
/** 
 * Called when a ping is received.  These pings are generally sent by the
 * server.  The correct method of handling these would be to respond to them
 * with -sendPongWithArgument: using <var>anArgument</var> as the argument.
 * The server that sent the ping is stored in <var>aSender</var>.
 */
- pingReceivedWithArgument: (NSString *)anArgument from: (NSString *)aSender
{
	return self;
}
/**
 * Called when a pong is received.  These are generally in answer to a 
 * ping sent with -sendPingWithArgument:  The argument <var>anArgument</var>
 * is generally the same as the argument sent with the ping.  <var>aSender</var>
 * is the server that sent out the pong.
 */
- pongReceivedWithArgument: (NSString *)anArgument from: (NSString *)aSender
{
	return self;
}
/**
 * Called when a new nickname was needed while registering because the other
 * one was either invalid or already taken.  Without overriding this, this
 * method will simply try adding a underscore onto it until it gets in. 
 * This method can be overridden to do other nickname-changing schemes.  The
 * new nickname should be directly set with -changeNick:
 */
- newNickNeededWhileRegistering
{
	[self changeNick: [NSString stringWithFormat: @"%@_", nick]];
	
	return self;
}
@end

@implementation IRCObject (LowLevel)
/**
 * Handles an incoming line of text from the IRC server by 
 * parsing it and doing the appropriate actions as well as 
 * calling any needed callbacks.
 * See [LineObject-lineReceived:] for more information.
 */
- lineReceived: (NSData *)aLine
{
	NSString *prefix = nil;
	NSString *command = nil;
	NSMutableArray *paramList = nil;
	id object;
	void (*function)(IRCObject *, NSString *, NSString *, NSArray *);
	NSString *line, *orig;
	
	orig = line = AUTORELEASE([[NSString alloc] initWithData: aLine
	  encoding: defaultEncoding]);

	if ([line length] == 0)
	{
		return self;
	}
	
	paramList = AUTORELEASE([NSMutableArray new]);
	
	line = get_IRC_prefix(line, &prefix); 
	
	if ([line length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject lineReceived: '@'] Line ended prematurely.",
		 orig];
	}

	line = get_next_IRC_word(line, &command);
	if (command == nil)
	{
		[NSException raise: IRCException
		 format: @"[IRCObject lineReceived: '@'] Line ended prematurely.",
		 orig];
	}

	while (1)
	{
		line = get_next_IRC_word(line, &object);
		if (!object)
		{
			break;
		}
		[paramList addObject: object];
	}
	
	if (is_numeric_command(command))
	{		
		if ([paramList count] >= 2)
		{
			NSRange aRange;

			[self setNick: [paramList objectAtIndex: 0]];

			aRange.location = 1;
			aRange.length = [paramList count] - 1;
		
			[self numericCommandReceived: command 
			  withParams: [paramList subarrayWithRange: aRange]
			  from: prefix];
		}	
	}
	else
	{
		function = NSMapGet(command_to_function, command);
		if (function != 0)
		{
			function(self, command, prefix, paramList);
		}
		else
		{
			NSLog(@"Could not handle :%@ %@ %@", prefix, command, paramList);
		}
	}

	if (!connected)
	{
		if ([command isEqualToString: ERR_NEEDMOREPARAMS] ||
			[command isEqualToString: ERR_ALREADYREGISTRED] ||
			[command isEqualToString: ERR_NONICKNAMEGIVEN])
		{
			[[NetApplication sharedInstance] disconnectObject: self];
			[self couldNotRegister: [NSString stringWithFormat:
			 @"%@ %@ %@", prefix, command, paramList]];
			return nil;
		}
		else if ([command isEqualToString: ERR_NICKNAMEINUSE] ||
		         [command isEqualToString: ERR_NICKCOLLISION] ||
				 [command isEqualToString: ERR_ERRONEUSNICKNAME])
		{
			[self newNickNeededWhileRegistering];
		}
		else if ([command isEqualToString: RPL_WELCOME])
		{
			connected = YES;
			[self registeredWithServer];
		}
	}
	
	return self;
}
- writeString: (NSString *)format, ...
{
	NSString *temp;
	va_list ap;

	va_start(ap, format);
	temp = AUTORELEASE([[NSString alloc] initWithFormat: format 
	  arguments: ap]);

	[(id <NetTransport>)transport writeData: [temp dataUsingEncoding: defaultEncoding]];
	
	if (![temp hasSuffix: @"\r\n"])
	{
		[(id <NetTransport>)transport writeData: IRC_new_line];
	}
	return self;
}
@end

/**
 *  001 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WELCOME = @"001";
/**
 *  002 - Please see RFC 1459 for additional information.
 */
NSString *RPL_YOURHOST = @"002";
/**
 *  003 - Please see RFC 1459 for additional information.
 */
NSString *RPL_CREATED = @"003";
/**
 *  004 - Please see RFC 1459 for additional information.
 */
NSString *RPL_MYINFO = @"004";
/**
 *  005 - Please see RFC 1459 for additional information.
 */
NSString *RPL_BOUNCE = @"005";
/**
 *  302 - Please see RFC 1459 for additional information.
 */
NSString *RPL_USERHOST = @"302";
/**
 *  303 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ISON = @"303";
/**
 *  301 - Please see RFC 1459 for additional information.
 */
NSString *RPL_AWAY = @"301";
/**
 *  305 - Please see RFC 1459 for additional information.
 */
NSString *RPL_UNAWAY = @"305";
/**
 *  306 - Please see RFC 1459 for additional information.
 */
NSString *RPL_NOWAWAY = @"306";
/**
 *  311 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOISUSER = @"311";
/**
 *  312 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOISSERVER = @"312";
/**
 *  313 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOISOPERATOR = @"313";
/**
 *  317 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOISIDLE = @"317";
/**
 *  318 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFWHOIS = @"318";
/**
 *  319 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOISCHANNELS = @"319";
/**
 *  314 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOWASUSER = @"314";
/**
 *  369 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFWHOWAS = @"369";
/**
 *  321 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LISTSTART = @"321";
/**
 *  322 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LIST = @"322";
/**
 *  323 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LISTEND = @"323";
/**
 *  325 - Please see RFC 1459 for additional information.
 */
NSString *RPL_UNIQOPIS = @"325";
/**
 *  324 - Please see RFC 1459 for additional information.
 */
NSString *RPL_CHANNELMODEIS = @"324";
/**
 *  331 - Please see RFC 1459 for additional information.
 */
NSString *RPL_NOTOPIC = @"331";
/**
 *  332 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TOPIC = @"332";
/**
 *  341 - Please see RFC 1459 for additional information.
 */
NSString *RPL_INVITING = @"341";
/**
 *  342 - Please see RFC 1459 for additional information.
 */
NSString *RPL_SUMMONING = @"342";
/**
 *  346 - Please see RFC 1459 for additional information.
 */
NSString *RPL_INVITELIST = @"346";
/**
 *  347 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFINVITELIST = @"347";
/**
 *  348 - Please see RFC 1459 for additional information.
 */
NSString *RPL_EXCEPTLIST = @"348";
/**
 *  349 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFEXCEPTLIST = @"349";
/**
 *  351 - Please see RFC 1459 for additional information.
 */
NSString *RPL_VERSION = @"351";
/**
 *  352 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOREPLY = @"352";
/**
 *  315 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFWHO = @"315";
/**
 *  353 - Please see RFC 1459 for additional information.
 */
NSString *RPL_NAMREPLY = @"353";
/**
 *  366 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFNAMES = @"366";
/**
 *  364 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LINKS = @"364";
/**
 *  365 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFLINKS = @"365";
/**
 *  367 - Please see RFC 1459 for additional information.
 */
NSString *RPL_BANLIST = @"367";
/**
 *  368 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFBANLIST = @"368";
/**
 *  371 - Please see RFC 1459 for additional information.
 */
NSString *RPL_INFO = @"371";
/**
 *  374 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFINFO = @"374";
/**
 *  375 - Please see RFC 1459 for additional information.
 */
NSString *RPL_MOTDSTART = @"375";
/**
 *  372 - Please see RFC 1459 for additional information.
 */
NSString *RPL_MOTD = @"372";
/**
 *  376 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFMOTD = @"376";
/**
 *  381 - Please see RFC 1459 for additional information.
 */
NSString *RPL_YOUREOPER = @"381";
/**
 *  382 - Please see RFC 1459 for additional information.
 */
NSString *RPL_REHASHING = @"382";
/**
 *  383 - Please see RFC 1459 for additional information.
 */
NSString *RPL_YOURESERVICE = @"383";
/**
 *  391 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TIME = @"391";
/**
 *  392 - Please see RFC 1459 for additional information.
 */
NSString *RPL_USERSSTART = @"392";
/**
 *  393 - Please see RFC 1459 for additional information.
 */
NSString *RPL_USERS = @"393";
/**
 *  394 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFUSERS = @"394";
/**
 *  395 - Please see RFC 1459 for additional information.
 */
NSString *RPL_NOUSERS = @"395";
/**
 *  200 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACELINK = @"200";
/**
 *  201 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACECONNECTING = @"201";
/**
 *  202 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACEHANDSHAKE = @"202";
/**
 *  203 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACEUNKNOWN = @"203";
/**
 *  204 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACEOPERATOR = @"204";
/**
 *  205 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACEUSER = @"205";
/**
 *  206 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACESERVER = @"206";
/**
 *  207 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACESERVICE = @"207";
/**
 *  208 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACENEWTYPE = @"208";
/**
 *  209 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACECLASS = @"209";
/**
 *  210 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACERECONNECT = @"210";
/**
 *  261 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACELOG = @"261";
/**
 *  262 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRACEEND = @"262";
/**
 *  211 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSLINKINFO = @"211";
/**
 *  212 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSCOMMANDS = @"212";
/**
 *  219 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFSTATS = @"219";
/**
 *  242 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSUPTIME = @"242";
/**
 *  243 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSOLINE = @"243";
/**
 *  221 - Please see RFC 1459 for additional information.
 */
NSString *RPL_UMODEIS = @"221";
/**
 *  234 - Please see RFC 1459 for additional information.
 */
NSString *RPL_SERVLIST = @"234";
/**
 *  235 - Please see RFC 1459 for additional information.
 */
NSString *RPL_SERVLISTEND = @"235";
/**
 *  251 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LUSERCLIENT = @"251";
/**
 *  252 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LUSEROP = @"252";
/**
 *  253 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LUSERUNKNOWN = @"253";
/**
 *  254 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LUSERCHANNELS = @"254";
/**
 *  255 - Please see RFC 1459 for additional information.
 */
NSString *RPL_LUSERME = @"255";
/**
 *  256 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ADMINME = @"256";
/**
 *  257 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ADMINLOC1 = @"257";
/**
 *  258 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ADMINLOC2 = @"258";
/**
 *  259 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ADMINEMAIL = @"259";
/**
 *  263 - Please see RFC 1459 for additional information.
 */
NSString *RPL_TRYAGAIN = @"263";
/**
 *  401 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOSUCHNICK = @"401";
/**
 *  402 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOSUCHSERVER = @"402";
/**
 *  403 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOSUCHCHANNEL = @"403";
/**
 *  404 - Please see RFC 1459 for additional information.
 */
NSString *ERR_CANNOTSENDTOCHAN = @"404";
/**
 *  405 - Please see RFC 1459 for additional information.
 */
NSString *ERR_TOOMANYCHANNELS = @"405";
/**
 *  406 - Please see RFC 1459 for additional information.
 */
NSString *ERR_WASNOSUCHNICK = @"406";
/**
 *  407 - Please see RFC 1459 for additional information.
 */
NSString *ERR_TOOMANYTARGETS = @"407";
/**
 *  408 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOSUCHSERVICE = @"408";
/**
 *  409 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOORIGIN = @"409";
/**
 *  411 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NORECIPIENT = @"411";
/**
 *  412 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOTEXTTOSEND = @"412";
/**
 *  413 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOTOPLEVEL = @"413";
/**
 *  414 - Please see RFC 1459 for additional information.
 */
NSString *ERR_WILDTOPLEVEL = @"414";
/**
 *  415 - Please see RFC 1459 for additional information.
 */
NSString *ERR_BADMASK = @"415";
/**
 *  421 - Please see RFC 1459 for additional information.
 */
NSString *ERR_UNKNOWNCOMMAND = @"421";
/**
 *  422 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOMOTD = @"422";
/**
 *  423 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOADMININFO = @"423";
/**
 *  424 - Please see RFC 1459 for additional information.
 */
NSString *ERR_FILEERROR = @"424";
/**
 *  431 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NONICKNAMEGIVEN = @"431";
/**
 *  432 - Please see RFC 1459 for additional information.
 */
NSString *ERR_ERRONEUSNICKNAME = @"432";
/**
 *  433 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NICKNAMEINUSE = @"433";
/**
 *  436 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NICKCOLLISION = @"436";
/**
 *  437 - Please see RFC 1459 for additional information.
 */
NSString *ERR_UNAVAILRESOURCE = @"437";
/**
 *  441 - Please see RFC 1459 for additional information.
 */
NSString *ERR_USERNOTINCHANNEL = @"441";
/**
 *  442 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOTONCHANNEL = @"442";
/**
 *  443 - Please see RFC 1459 for additional information.
 */
NSString *ERR_USERONCHANNEL = @"443";
/**
 *  444 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOLOGIN = @"444";
/**
 *  445 - Please see RFC 1459 for additional information.
 */
NSString *ERR_SUMMONDISABLED = @"445";
/**
 *  446 - Please see RFC 1459 for additional information.
 */
NSString *ERR_USERSDISABLED = @"446";
/**
 *  451 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOTREGISTERED = @"451";
/**
 *  461 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NEEDMOREPARAMS = @"461";
/**
 *  462 - Please see RFC 1459 for additional information.
 */
NSString *ERR_ALREADYREGISTRED = @"462";
/**
 *  463 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOPERMFORHOST = @"463";
/**
 *  464 - Please see RFC 1459 for additional information.
 */
NSString *ERR_PASSWDMISMATCH = @"464";
/**
 *  465 - Please see RFC 1459 for additional information.
 */
NSString *ERR_YOUREBANNEDCREEP = @"465";
/**
 *  466 - Please see RFC 1459 for additional information.
 */
NSString *ERR_YOUWILLBEBANNED = @"466";
/**
 *  467 - Please see RFC 1459 for additional information.
 */
NSString *ERR_KEYSET = @"467";
/**
 *  471 - Please see RFC 1459 for additional information.
 */
NSString *ERR_CHANNELISFULL = @"471";
/**
 *  472 - Please see RFC 1459 for additional information.
 */
NSString *ERR_UNKNOWNMODE = @"472";
/**
 *  473 - Please see RFC 1459 for additional information.
 */
NSString *ERR_INVITEONLYCHAN = @"473";
/**
 *  474 - Please see RFC 1459 for additional information.
 */
NSString *ERR_BANNEDFROMCHAN = @"474";
/**
 *  475 - Please see RFC 1459 for additional information.
 */
NSString *ERR_BADCHANNELKEY = @"475";
/**
 *  476 - Please see RFC 1459 for additional information.
 */
NSString *ERR_BADCHANMASK = @"476";
/**
 *  477 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOCHANMODES = @"477";
/**
 *  478 - Please see RFC 1459 for additional information.
 */
NSString *ERR_BANLISTFULL = @"478";
/**
 *  481 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOPRIVILEGES = @"481";
/**
 *  482 - Please see RFC 1459 for additional information.
 */
NSString *ERR_CHANOPRIVSNEEDED = @"482";
/**
 *  483 - Please see RFC 1459 for additional information.
 */
NSString *ERR_CANTKILLSERVER = @"483";
/**
 *  484 - Please see RFC 1459 for additional information.
 */
NSString *ERR_RESTRICTED = @"484";
/**
 *  485 - Please see RFC 1459 for additional information.
 */
NSString *ERR_UNIQOPPRIVSNEEDED = @"485";
/**
 *  491 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOOPERHOST = @"491";
/**
 *  501 - Please see RFC 1459 for additional information.
 */
NSString *ERR_UMODEUNKNOWNFLAG = @"501";
/**
 *  502 - Please see RFC 1459 for additional information.
 */
NSString *ERR_USERSDONTMATCH = @"502";
/**
 *  231 - Please see RFC 1459 for additional information.
 */
NSString *RPL_SERVICEINFO = @"231";
/**
 *  232 - Please see RFC 1459 for additional information.
 */
NSString *RPL_ENDOFSERVICES = @"232";
/**
 *  233 - Please see RFC 1459 for additional information.
 */
NSString *RPL_SERVICE = @"233";
/**
 *  300 - Please see RFC 1459 for additional information.
 */
NSString *RPL_NONE = @"300";
/**
 *  316 - Please see RFC 1459 for additional information.
 */
NSString *RPL_WHOISCHANOP = @"316";
/**
 *  361 - Please see RFC 1459 for additional information.
 */
NSString *RPL_KILLDONE = @"361";
/**
 *  262 - Please see RFC 1459 for additional information.
 */
NSString *RPL_CLOSING = @"262";
/**
 *  363 - Please see RFC 1459 for additional information.
 */
NSString *RPL_CLOSEEND = @"363";
/**
 *  373 - Please see RFC 1459 for additional information.
 */
NSString *RPL_INFOSTART = @"373";
/**
 *  384 - Please see RFC 1459 for additional information.
 */
NSString *RPL_MYPORTIS = @"384";
/**
 *  213 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSCLINE = @"213";
/**
 *  214 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSNLINE = @"214";
/**
 *  215 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSILINE = @"215";
/**
 *  216 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSKLINE = @"216";
/**
 *  217 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSQLINE = @"217";
/**
 *  218 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSYLINE = @"218";
/**
 *  240 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSVLINE = @"240";
/**
 *  241 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSLLINE = @"241";
/**
 *  244 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSHLINE = @"244";
/**
 *  245 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSSLINE = @"245";
/**
 *  246 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSPING = @"246";
/**
 *  247 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSBLINE = @"247";
/**
 *  250 - Please see RFC 1459 for additional information.
 */
NSString *RPL_STATSDLINE = @"250";
/**
 *  492 - Please see RFC 1459 for additional information.
 */
NSString *ERR_NOSERVICEHOST = @"492";
