/***************************************************************************
                                IRCClient.m
                          -------------------
    begin                : Thu May 30 22:06:25 UTC 2002
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

#import "NetBase.h"
#import "NetTCP.h"
#import "IRCClient.h"

#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSProcessInfo.h>

#include <string.h>

NSString *IRCException = @"IRCException";

static NSMapTable *command_to_function = 0;
static NSMapTable *numeric_to_function = 0;

static NSData *IRC_new_line = nil;

#define REMOVE_SPACES(__buffer, __bufferEnd)\
while (*__buffer == ' ') {\
	__buffer++;\
	if (__buffer == __bufferEnd) {\
		*offset = -1;\
		return nil;\
	}\
}

static inline NSString *get_IRC_prefix(NSData *data, int *offset)
{
	const char *memBegin = [data bytes];
	const char *mem = memBegin;
	const char *memEnd = mem + [data length];
	const char *temp;
	
	REMOVE_SPACES(mem, memEnd);

	if (*mem != ':')
	{
		return nil;
	}
	mem++;
	
	temp = memchr(mem, ' ', memEnd - mem);

	if (temp == 0)
	{
		*offset = -1;
		return nil;
	}
	
	*offset = temp - memBegin;
	return [NSString stringWithCString: mem length: temp - mem];
}
	
static inline NSString *get_next_IRC_word(NSData *data, int *offset)
{
	const char *memBegin = [data bytes];
	const char *mem = memBegin;
	const char *memEnd = mem + [data length];
	const char *temp;
	
	mem += *offset;

	REMOVE_SPACES(mem, memEnd);

	if (*mem == ':')
	{
		*offset = -1;
		mem++;
		return [NSString stringWithCString: mem length: memEnd - mem];
	}

	temp = memchr(mem, ' ', memEnd - mem);
	
	if (!temp)
	{
		*offset = -1;
		return [NSString stringWithCString: mem length: memEnd - mem];
	}

	*offset = temp - memBegin;
	return [NSString stringWithCString: mem length: temp - mem];
}

#undef REMOVE_SPACES

static inline BOOL contains_a_space(NSString *aString)
{
	return (strchr([aString cString], ' ')) ? YES : NO;
}	

static inline NSString *string_to_character(NSString *aString, int c)
{
	const char *temp = [aString cString];
	const char *test;

	if (!aString)
	{
		return nil;
	}

	test = strchr(temp, c);

	if (!test)
	{
		return aString;
	}
	
	return [NSString stringWithCString: temp length: test - temp];
}

inline NSString *ExtractIRCNick(NSString *prefix)
{	
	const char *temp = [prefix cString];
	const char *test;

	if (!prefix)
	{
		return nil;
	}

	test = strchr(temp, '!');

	if (!test)
	{
		return prefix;
	}

	return [NSString stringWithCString: temp length: test - temp];
}

inline NSString *ExtractIRCHost(NSString *prefix)
{
	const char *temp = [prefix cString];
	const char *test;

	if (!prefix)
	{
		return nil;
	}

	test = strchr(temp, '!');

	if (!test)
	{
		return nil;
	}

	return [NSString stringWithCString: temp + 1];
}

inline NSArray *SeparateIRCNickAndHost(NSString *prefix)
{
	const char *temp = [prefix cString];
	const char *test;

	if (!prefix)
	{
		return nil;
	}

	test = strchr(temp, '!');

	if (!test)
	{
		return [NSArray arrayWithObject: prefix];
	}

	return [NSArray arrayWithObjects: 
	 [NSString stringWithCString: temp length: test - temp],
	 [NSString stringWithCString: temp + 1],
	 nil];
}

static void rec_nick(IRCClient *client, NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}
		
	if ([paramList count] == 0)
	{
		return;
	}

	[client changedNickFrom: prefix to: [paramList objectAtIndex: 0]];
}

static void rec_join(IRCClient *client, NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}

	if ([paramList count] == 0)
	{
		return;
	}

	[client joinedChannel: [paramList objectAtIndex: 0] by: prefix];
}

static void rec_part(IRCClient *client, NSString *prefix, NSArray *paramList)
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

	[client partedChannel: [paramList objectAtIndex: 0] withMessage:
	  (x == 2) ? [paramList objectAtIndex: 1] : 0 by: prefix];
}

static void rec_quit(IRCClient *client, NSString *prefix, NSArray *paramList)
{
	if (!prefix)
	{
		return;
	}

	if ([paramList count] == 0)
	{
		return;
	}

	[client quitIRCWithMessage: [paramList objectAtIndex: 0] by: prefix];
}

static void rec_topic(IRCClient *client, NSString *prefix, NSArray *paramList)
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
	  in: [paramList objectAtIndex: 0] by: prefix];
}

static void rec_privmsg(IRCClient *client, NSString *prefix, NSArray *paramList)
{
	NSRange aRange = {0, 7};
	int x;
	id message;
	
	if (!prefix)
	{
		return;
	}

	if ([paramList count] < 2)
	{
		return;
	}

	message = [paramList objectAtIndex: 1];
	x = [message length];
	if (x > 8)
	{
		if ([message compare: @"\001ACTION " options: NSCaseInsensitiveSearch
		               range: aRange] == NSOrderedSame)
		{
			aRange.location = 9;
			aRange.length = x - 9;
			[client actionReceived: [message substringWithRange: aRange]
			   from: prefix to: [paramList objectAtIndex: 0]];
			return;
		}
	}	
	[client messageReceived: message from: prefix
	                     to: [paramList objectAtIndex: 0]];
}

@interface IRCClient (InternalIRCClient)
- setInitialNicknames: (NSArray *)names;
- setNick: (NSString *)aNick;
- setServer: (NSString *)aServer;
@end

@implementation IRCClient (InternalIRCClient)
- setInitialNicknames: (NSArray *)names
{
	if (!connected)
	{
		RELEASE(initialNicknames);
		initialNicknames = RETAIN(names);
	}
	return self;
}
- setNick: (NSString *)aNick
{
	RELEASE(nick);
	nick = RETAIN(aNick);
	return self;
}
- setServer: (NSString *)aServer
{
	RELEASE(server);
	server = RETAIN(aServer);
	return self;
}
@end

@implementation IRCClient
+ (void)initialize
{
	IRC_new_line = [[NSData alloc] initWithBytes: "\r\n" length: 2];

	command_to_function = NSCreateMapTable(NSObjectMapKeyCallBacks,
	   NSIntMapValueCallBacks, 100);
	
	numeric_to_function = NSCreateMapTable(NSObjectMapKeyCallBacks,
	   NSIntMapValueCallBacks, 100);
	   
	NSMapInsert(command_to_function, @"NICK", rec_nick);
	NSMapInsert(command_to_function, @"JOIN", rec_join);
	NSMapInsert(command_to_function, @"PART", rec_part);
	NSMapInsert(command_to_function, @"QUIT", rec_quit);
	NSMapInsert(command_to_function, @"TOPIC", rec_topic);
	NSMapInsert(command_to_function, @"PRIVMSG", rec_privmsg);

}
+ (IRCClient *)connectTo: (NSString *)host onPort: (int)aPort
   withTimeout: (int)timeout withNicknames: (NSArray *)nicknames
   withUserName: (NSString *)user withRealName: (NSString *)realName
   withPassword: (NSString *)password withClass: (Class)aClass
{
	IRCClient *connection;
	NSEnumerator *iter = [nicknames objectEnumerator];
	NSMutableArray *array = AUTORELEASE([NSMutableArray new]);
	id object;

	if ([nicknames count] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCClient connectTo...] No nicknames provided"];
	}
	
	while ((object = [iter nextObject]))
	{
		object = string_to_character(object, ' ');
		if ([object length] == 0)
		{
			continue;
		}
		[array addObject: object];
	}
	
	if ([array count] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCClient connectTo...] No usable nicknames provided"];
	}
	
	if ([host length] == 0)
	{
		[NSException raise: IRCException
		 format: @"[IRCClient connectTo...] No host provided"];
	}

	if (aPort <= 0)
	{
		aPort = 6667;
	}
	
	if ([password length])
	{
		if (contains_a_space(password))
		{
			[NSException raise: IRCException
			 format: @"[IRCClient connectTo...] Password contains a space"];
		}
	}
	else
	{
		password = nil;
	}
	
	if ([user length] == 0)
	{
		id enviro;
		enviro = [[NSProcessInfo processInfo] environment];

		user = [enviro objectForKey: @"LOGNAME"];
		
		if ([user length] == 0)
		{
			user = @"netclasses";
		}
	}
	if ([(user = string_to_character(user, ' ')) length] == 0)
	{
		user = @"netclasses";
	}

	if ([realName length] == 0)
	{
		realName = @"John Doe";
	}
	
	connection = [[TCPSystem sharedInstance] connectNetObject: aClass
	 toHost: host onPort: aPort withTimeout: timeout];
	
	if (!connection)
	{
		[NSException raise: IRCException
		 format: @"[IRCClient connectTo...] Couldn't connect: '%@'", 
		 [[TCPSystem sharedInstance] errorString]];
	}
	
	if (password)
	{
		[connection writeString: @"PASS %@", password];
	}

	[connection setInitialNicknames: array];
	
	object = [array objectAtIndex: 0];
	[connection setNick: object];
	[connection setServer: host];
	
	[connection changeNick: object];
	
	[connection writeString: @"USER %@ %@ %@ :%@", user, @"localhost",
	 @"netclasses", realName];
	
	
	return self;
}		  
- connectionEstablished: aTransport
{
	[super connectionEstablished: aTransport];
	return self;
}
- (void)connectionLost
{
	DESTROY(nick);
	[super connectionLost];
}
- (BOOL)connected
{
	return connected;
}
- (NSString *)nick
{
	return nick;
}
- (NSString *)server
{
	return server;
}
- changeNick: (NSString *)aNick
{
	if ([aNick length] > 0)
	{
		if (contains_a_space(aNick))
		{
			[NSException raise: IRCException
			 format: @"[IRCClient changeNick: '%@'] Nickname contains a space",
			  aNick];
		}
					
		[self writeString: @"NICK %@", aNick];
	}
	return self;
}
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
- partChannel: (NSString *)channel withMessage: (NSString *)aMessage
{
	if ([channel length] == 0)
	{
		return self;
	}
	
	if (contains_a_space(channel))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient partChannel: '%@' ...] Channel contains a space",
		  channel];
	}
	
	if ([aMessage length] > 0)
	{
		[self writeString: @"PART %@ :%@", channel, aMessage];
	}
	else
	{
		[self writeString: @"PART %@", channel];
	}
	
	return self;
}
- joinChannel: (NSString *)channel withPassword: (NSString *)aPassword
{
	if ([channel length] == 0)
	{
		return self;
	}

	if (contains_a_space(channel))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient joinChannel: '%@' ...] Channel contains a space",
		  channel];
	}

	if ([aPassword length] == 0)
	{
		[self writeString: @"JOIN %@", channel];
		return self;
	}

	if (contains_a_space(aPassword))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient joinChannel: withPassword: '%@'] Password contains a space.",
		  aPassword];
	}

	[self writeString: @"JOIN %@ %@", channel, aPassword];

	return self;
}
- sendMessage: (NSString *)message to: (NSString *)receiver
{
	if ([message length] == 0)
	{
		return self;
	}
	if ([receiver length] == 0)
	{
		return self;
	}
	if (contains_a_space(receiver))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient sendMessage: '%@' to: '%@'] The receiver contains a space.",
		  message, receiver];
	}
	
	[self writeString: @"PRIVMSG %@ :%@", receiver, message];
	
	return self;
}
- sendAction: (NSString *)anAction to: (NSString *)whom
{
	if ([anAction length] == 0)
	{
		return self;
	}
	if ([whom length] == 0)
	{
		return self;
	}
	if (contains_a_space(whom))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient sendAction: '%@' to: '%@'] The receiver contsins a space.",
		   anAction, whom];
	}

	[self writeString: @"PRIVMSG %@ :\001ACTION %@\001", whom, anAction];
	
	return self;
}
- becomeOperatorWithName: (NSString *)aName withPassword: (NSString *)pass
{
	if (([aName length] == 0) || ([pass length] == 0))
	{
		return self;
	}
	if (contains_a_space(pass))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient becomeOperatorWithName: %@ withPassword: %@] The password contains a space.",
		  aName, pass];
	}
	if (contains_a_space(aName))
	{
		[NSException raise: IRCException
		 format: @"[IRCClient becomeOperatorWithName: %@ withPassword: %@] The name contains a space.",
		  aName, pass];
	}
	
	[self writeString: @"OPER %@ %@", aName, pass];
	
	return self;
}

- registeredWithServer
{
	return self;
}
- couldNotRegister: (NSString *)reason
{
	return self;
}
- changedNickFrom: (NSString *)formerName to: (NSString *)newName
{
	if ([ExtractIRCNick(formerName) caseInsensitiveCompare: nick] 
	      == NSOrderedSame)
	{
		RELEASE(nick);
		nick = RETAIN(newName);
	}
	return self;
}
- joinedChannel: (NSString *)channel by: (NSString *)whom
{
	return self;
}
- partedChannel: (NSString *)channel withMessage: (NSString *)aMessage
             by: (NSString *)whom
{
	return self;
}
- quitIRCWithMessage: (NSString *)aMessage by: (NSString *)whom
{
	return self;
}
- topicChangedTo: (NSString *)aTopic in: (NSString *)channel
              by: (NSString *)whom
{
	return self;
}
- messageReceived: (NSString *)aMessage from: (NSString *)from 
               to: (NSString *)to
{
	return self;
}
- actionReceived: (NSString *)anAction from: (NSString *)from 
               to: (NSString *)to
{
	return self;
}
- lineReceived: (NSData *)aLine
{
	NSString *prefix = nil;
	NSString *command = nil;
	NSMutableArray *paramList = nil;
	int offset = 0;
	id object;
	void (*function)(IRCClient *, NSString *, NSArray *);

	if ([aLine length] == 0)
	{
		return self;
	}
	paramList = AUTORELEASE([NSMutableArray new]);
	
	prefix = get_IRC_prefix(aLine, &offset);
	if (offset == -1)
	{
		[NSException raise: IRCException
		 format: @"[IRCClient lineReceived: '@'] Line ended prematurely.",
		 [NSString stringWithCString: [aLine bytes] length: [aLine length]]];
	}

	command = get_next_IRC_word(aLine, &offset);
	if (command == nil)
	{
		[NSException raise: IRCException
		 format: @"[IRCClient lineReceived: '@'] Line ended prematurely.",
		 [NSString stringWithCString: [aLine bytes] length: [aLine length]]];
	}

	while (offset != -1)
	{
		object = get_next_IRC_word(aLine, &offset);
		if (!object)
		{
			break;
		}
		[paramList addObject: object];
	}

	if (!connected)
	{
		if ([command isEqualToString: ERR_ERRONEUSNICKNAME] || 
		    [command isEqualToString: ERR_NEEDMOREPARAMS] ||
			[command isEqualToString: ERR_ALREADYREGISTRED] ||
			[command isEqualToString: ERR_NONICKNAMEGIVEN] ||
			[command isEqualToString: ERR_NICKCOLLISION])
		{
			[[NetApplication sharedInstance] disconnectObject: self];
			[self couldNotRegister: [NSString stringWithFormat:
			 @"%@ %@ %@", prefix, command, paramList]];
			return nil;
		}
		else if ([command isEqualToString: ERR_NICKNAMEINUSE])
		{
			int actualIndex = ((++nicknameIndex) >= [initialNicknames count]) ? 
			                  0 : nicknameIndex;
			int underscores = (actualIndex == 0) ? nicknameIndex : 0;
			
			nick = RETAIN([initialNicknames objectAtIndex: actualIndex]);
			
			if (underscores > 0)
			{
				char *buffer = malloc(underscores);
				memset(buffer, '_', underscores);
				
				AUTORELEASE(nick);
				nick = RETAIN([nick stringByAppendingString:
				 [NSString stringWithCString: buffer length: underscores]]);

				free(buffer);
			}

			[self changeNick: nick];
			return self;
		}
		else if ([command isEqualToString: RPL_WELCOME])
		{
			connected = YES;
			[self registeredWithServer];
		}
	}
	
	function = NSMapGet(command_to_function, command);
	if (function != 0)
	{
		function(self, prefix, paramList);
	}
	
	return self;
}
- writeString: (NSString *)format, ...
{
	NSString *temp;
	va_list ap;

	va_start(ap, format);
	temp = [NSString stringWithFormat: format arguments: ap];

	[transport writeData: [NSData dataWithBytes: [temp cString]
	                                     length: [temp cStringLength]]];
	
	if (![temp hasSuffix: @"\r\n"])
	{
		[transport writeData: IRC_new_line];
	}
	return self;
}
@end

NSString *RPL_WELCOME = @"001";
NSString *RPL_YOURHOST = @"002";
NSString *RPL_CREATED = @"003";
NSString *RPL_MYINFO = @"004";
NSString *RPL_BOUNCE = @"005";
NSString *RPL_USERHOST = @"302";
NSString *RPL_ISON = @"303";
NSString *RPL_AWAY = @"301";
NSString *RPL_UNAWAY = @"305";
NSString *RPL_NOWAWAY = @"306";
NSString *RPL_WHOISUSER = @"311";
NSString *RPL_WHOISSERVER = @"312";
NSString *RPL_WHOISOPERATOR = @"313";
NSString *RPL_WHOISIDLE = @"317";
NSString *RPL_ENDOFWHOIS = @"318";
NSString *RPL_WHOISCHANNELS = @"319";
NSString *RPL_WHOWASUSER = @"314";
NSString *RPL_ENDOFWHOWAS = @"369";
NSString *RPL_LISTSTART = @"321";
NSString *RPL_LIST = @"322";
NSString *RPL_LISTEND = @"323";
NSString *RPL_UNIQOPIS = @"325";
NSString *RPL_CHANNELMODEIS = @"324";
NSString *RPL_NOTOPIC = @"331";
NSString *RPL_TOPIC = @"332";
NSString *RPL_INVITING = @"341";
NSString *RPL_SUMMONING = @"342";
NSString *RPL_INVITELIST = @"346";
NSString *RPL_ENDOFINVITELIST = @"347";
NSString *RPL_EXCEPTLIST = @"348";
NSString *RPL_ENDOFEXCEPTLIST = @"349";
NSString *RPL_VERSION = @"351";
NSString *RPL_WHOREPLY = @"352";
NSString *RPL_ENDOFWHO = @"315";
NSString *RPL_NAMREPLY = @"353";
NSString *RPL_ENDOFNAMES = @"366";
NSString *RPL_LINKS = @"364";
NSString *RPL_ENDOFLINKS = @"365";
NSString *RPL_BANLIST = @"367";
NSString *RPL_ENDOFBANLIST = @"368";
NSString *RPL_INFO = @"371";
NSString *RPL_ENDOFINFO = @"374";
NSString *RPL_MOTDSTART = @"375";
NSString *RPL_MOTD = @"372";
NSString *RPL_ENDOFMOTD = @"376";
NSString *RPL_YOUREOPER = @"381";
NSString *RPL_REHASHING = @"382";
NSString *RPL_YOURESERVICE = @"383";
NSString *RPL_TIME = @"391";
NSString *RPL_USERSSTART = @"392";
NSString *RPL_USERS = @"393";
NSString *RPL_ENDOFUSERS = @"394";
NSString *RPL_NOUSERS = @"395";
NSString *RPL_TRACELINK = @"200";
NSString *RPL_TRACECONNECTING = @"201";
NSString *RPL_TRACEHANDSHAKE = @"202";
NSString *RPL_TRACEUNKNOWN = @"203";
NSString *RPL_TRACEOPERATOR = @"204";
NSString *RPL_TRACEUSER = @"205";
NSString *RPL_TRACESERVER = @"206";
NSString *RPL_TRACESERVICE = @"207";
NSString *RPL_TRACENEWTYPE = @"208";
NSString *RPL_TRACECLASS = @"209";
NSString *RPL_TRACERECONNECT = @"210";
NSString *RPL_TRACELOG = @"261";
NSString *RPL_TRACEEND = @"262";
NSString *RPL_STATSLINKINFO = @"211";
NSString *RPL_STATSCOMMANDS = @"212";
NSString *RPL_ENDOFSTATS = @"219";
NSString *RPL_STATSUPTIME = @"242";
NSString *RPL_STATSOLINE = @"243";
NSString *RPL_UMODEIS = @"221";
NSString *RPL_SERVLIST = @"234";
NSString *RPL_SERVLISTEND = @"235";
NSString *RPL_LUSERCLIENT = @"251";
NSString *RPL_LUSEROP = @"252";
NSString *RPL_LUSERUNKNOWN = @"253";
NSString *RPL_LUSERCHANNELS = @"254";
NSString *RPL_LUSERME = @"255";
NSString *RPL_ADMINME = @"256";
NSString *RPL_ADMINLOC1 = @"257";
NSString *RPL_ADMINLOC2 = @"258";
NSString *RPL_ADMINEMAIL = @"259";
NSString *RPL_TRYAGAIN = @"263";
NSString *ERR_NOSUCHNICK = @"401";
NSString *ERR_NOSUCHSERVER = @"402";
NSString *ERR_NOSUCHCHANNEL = @"403";
NSString *ERR_CANNOTSENDTOCHAN = @"404";
NSString *ERR_TOOMANYCHANNELS = @"405";
NSString *ERR_WASNOSUCHNICK = @"406";
NSString *ERR_TOOMANYTARGETS = @"407";
NSString *ERR_NOSUCHSERVICE = @"408";
NSString *ERR_NOORIGIN = @"409";
NSString *ERR_NORECIPIENT = @"411";
NSString *ERR_NOTEXTTOSEND = @"412";
NSString *ERR_NOTOPLEVEL = @"413";
NSString *ERR_WILDTOPLEVEL = @"414";
NSString *ERR_BADMASK = @"415";
NSString *ERR_UNKNOWNCOMMAND = @"421";
NSString *ERR_NOMOTD = @"422";
NSString *ERR_NOADMININFO = @"423";
NSString *ERR_FILEERROR = @"424";
NSString *ERR_NONICKNAMEGIVEN = @"431";
NSString *ERR_ERRONEUSNICKNAME = @"432";
NSString *ERR_NICKNAMEINUSE = @"433";
NSString *ERR_NICKCOLLISION = @"436";
NSString *ERR_UNAVAILRESOURCE = @"437";
NSString *ERR_USERNOTINCHANNEL = @"441";
NSString *ERR_NOTONCHANNEL = @"442";
NSString *ERR_USERONCHANNEL = @"443";
NSString *ERR_NOLOGIN = @"444";
NSString *ERR_SUMMONDISABLED = @"445";
NSString *ERR_USERSDISABLED = @"446";
NSString *ERR_NOTREGISTERED = @"451";
NSString *ERR_NEEDMOREPARAMS = @"461";
NSString *ERR_ALREADYREGISTRED = @"462";
NSString *ERR_NOPERMFORHOST = @"463";
NSString *ERR_PASSWDMISMATCH = @"464";
NSString *ERR_YOUREBANNEDCREEP = @"465";
NSString *ERR_YOUWILLBEBANNED = @"466";
NSString *ERR_KEYSET = @"467";
NSString *ERR_CHANNELISFULL = @"471";
NSString *ERR_UNKNOWNMODE = @"472";
NSString *ERR_INVITEONLYCHAN = @"473";
NSString *ERR_BANNEDFROMCHAN = @"474";
NSString *ERR_BADCHANNELKEY = @"475";
NSString *ERR_BADCHANMASK = @"476";
NSString *ERR_NOCHANMODES = @"477";
NSString *ERR_BANLISTFULL = @"478";
NSString *ERR_NOPRIVILEGES = @"481";
NSString *ERR_CHANOPRIVSNEEDED = @"482";
NSString *ERR_CANTKILLSERVER = @"483";
NSString *ERR_RESTRICTED = @"484";
NSString *ERR_UNIQOPPRIVSNEEDED = @"485";
NSString *ERR_NOOPERHOST = @"491";
NSString *ERR_UMODEUNKNOWNFLAG = @"501";
NSString *ERR_USERSDONTMATCH = @"502";
NSString *RPL_SERVICEINFO = @"231";
NSString *RPL_ENDOFSERVICES = @"232";
NSString *RPL_SERVICE = @"233";
NSString *RPL_NONE = @"300";
NSString *RPL_WHOISCHANOP = @"316";
NSString *RPL_KILLDONE = @"361";
NSString *RPL_CLOSING = @"262";
NSString *RPL_CLOSEEND = @"363";
NSString *RPL_INFOSTART = @"373";
NSString *RPL_MYPORTIS = @"384";
NSString *RPL_STATSCLINE = @"213";
NSString *RPL_STATSNLINE = @"214";
NSString *RPL_STATSILINE = @"215";
NSString *RPL_STATSKLINE = @"216";
NSString *RPL_STATSQLINE = @"217";
NSString *RPL_STATSYLINE = @"218";
NSString *RPL_STATSVLINE = @"240";
NSString *RPL_STATSLLINE = @"241";
NSString *RPL_STATSHLINE = @"244";
NSString *RPL_STATSSLINE = @"245";
NSString *RPL_STATSPING = @"246";
NSString *RPL_STATSBLINE = @"247";
NSString *RPL_STATSDLINE = @"250";
NSString *ERR_NOSERVICEHOST = @"492";
