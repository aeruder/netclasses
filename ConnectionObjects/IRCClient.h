/***************************************************************************
                                IRCClient.h
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

#import "LineObject.h"
#import <Foundation/NSObject.h>

@class NSString, NSMutableArray, NSArray, NSMutableDictionary;
@class NSMutableSet;

extern NSString *IRCException;

NSString *ExtractIRCNick(NSString *prefix);
NSString *ExtractIRCHost(NSString *prefix);

NSArray *SeparateIRCNickAndHost(NSString *prefix);

@interface IRCClient : LineObject
	{
		NSString *server;
		NSString *nick;
		int nicknameIndex;
		BOOL connected;
		
		NSMutableArray *initialNicknames;
	}
+ (IRCClient *)connectTo: (NSString *)host onPort: (int)aPort 
   withTimeout: (int)timeout withNicknames: (NSArray *)nicknames 
   withUserName: (NSString *)user withRealName: (NSString *)realName 
   withPassword: (NSString *)password withClass: (Class)aObject;
   
- (BOOL)connected;

- (NSString *)nick;

- (NSString *)server;

// IRC Operations
- changeNick: (NSString *)aNick;

- quitWithMessage: (NSString *)aMessage;

- partChannel: (NSString *)channel withMessage: (NSString *)aMessage;

- joinChannel: (NSString *)channel withPassword: (NSString *)aPassword;

- sendMessage: (NSString *)message to: (NSString *)receiver;

- sendNotice: (NSString *)message to: (NSString *)receiver;

- sendAction: (NSString *)anAction to: (NSString *)whom;

- becomeOperatorWithName: (NSString *)aName withPassword: (NSString *)pass;

- requestNamesOnChannel: (NSString *)aChannel fromServer: (NSString *)aServer;

- requestMOTDOnServer: (NSString *)aServer;

- requestSizeInformationFromServer: (NSString *)aServer
                      andForwardTo: (NSString *)anotherServer;

- requestVersionOfServer: (NSString *)aServer;

- requestServerStats: (NSString *)aServer for: (NSString *)query;

- requestServerLink: (NSString *)aLink from: (NSString *)aServer;

- requestTimeOnServer: (NSString *)aServer;

- requestServerToConnect: (NSString *)aServer to: (NSString *)connectServer
                  onPort: (NSString *)aPort;

- requestTraceOnServer: (NSString *)aServer;

- requestAdministratorOnServer: (NSString *)aServer;

- requestInfoOnServer: (NSString *)aServer;

- requestServiceListWithMask: (NSString *)aMask ofType: (NSString *)type;

- requestServerRehash;

- requestServerShutdown;

- requestServerRestart;

- requestUserInfoOnServer: (NSString *)aServer;

- areUsersOn: (NSString *)userList;

- sendWallops: (NSString *)message;

- queryService: (NSString *)aService withMessage: (NSString *)aMessage;

- listWho: (NSString *)aMask onlyOperators: (BOOL)operators;

- whois: (NSString *)aPerson onServer: (NSString *)aServer;

- whowas: (NSString *)aPerson onServer: (NSString *)aServer
                     withNumberEntries: (NSString *)aNumber;

- kill: (NSString *)aPerson withComment: (NSString *)aComment;

- setTopicForChannel: (NSString *)aChannel to: (NSString *)aTopic;

- setMode: (NSString *)aMode on: (NSString *)anObject 
                     withParams: (NSArray *)list;
					 
- listChannel: (NSString *)aChannel onServer: (NSString *)aServer;

- invite: (NSString *)aPerson to: (NSString *)aChannel;

- kick: (NSString *)aPerson offOf: (NSString *)aChannel for: (NSString *)reason;

- setAwayWithMessage: (NSString *)message;

// Callbacks
- registeredWithServer;

- couldNotRegister: (NSString *)reason;

- wallopsReceived: (NSString *)message by: (NSString *)whom;

- userKicked: (NSString *)aPerson from: (NSString *)aChannel 
         for: (NSString *)reason by: (NSString *)whom;
		 
- invitedTo: (NSString *)aChannel by: (NSString *)aPerson;

- modeChanged: (NSString *)mode on: (NSString *)anObject 
   withParams: (NSArray *)paramList by: (NSString *)whom;
   
- numericCommandReceived: (NSString *)command withParams: (NSArray *)paramList 
                      by: (NSString *)whom;

- nickChangedTo: (NSString *)newName by: (NSString *)whom;

- channelJoined: (NSString *)channel by: (NSString *)whom;

- channelParted: (NSString *)channel withMessage: (NSString *)aMessage
             by: (NSString *)whom;

- quitIRCWithMessage: (NSString *)aMessage by: (NSString *)whom;

- topicChangedTo: (NSString *)aTopic in: (NSString *)channel
              by: (NSString *)whom;

- messageReceived: (NSString *)aMessage to: (NSString *)to
               by: (NSString *)whom;

- noticeReceived: (NSString *)aMessage to: (NSString *)to
              by: (NSString *)whom;

- actionReceived: (NSString *)anAction to: (NSString *)to
              by: (NSString *)whom;

// Low-Level   
- lineReceived: (NSData *)aLine;

- writeString: (NSString *)format, ...;
@end

extern NSString *RPL_WELCOME;
extern NSString *RPL_YOURHOST;
extern NSString *RPL_CREATED;
extern NSString *RPL_MYINFO;
extern NSString *RPL_BOUNCE;
extern NSString *RPL_USERHOST;
extern NSString *RPL_ISON;
extern NSString *RPL_AWAY;
extern NSString *RPL_UNAWAY;
extern NSString *RPL_NOWAWAY;
extern NSString *RPL_WHOISUSER;
extern NSString *RPL_WHOISSERVER;
extern NSString *RPL_WHOISOPERATOR;
extern NSString *RPL_WHOISIDLE;
extern NSString *RPL_ENDOFWHOIS;
extern NSString *RPL_WHOISCHANNELS;
extern NSString *RPL_WHOWASUSER;
extern NSString *RPL_ENDOFWHOWAS;
extern NSString *RPL_LISTSTART;
extern NSString *RPL_LIST;
extern NSString *RPL_LISTEND;
extern NSString *RPL_UNIQOPIS;
extern NSString *RPL_CHANNELMODEIS;
extern NSString *RPL_NOTOPIC;
extern NSString *RPL_TOPIC;
extern NSString *RPL_INVITING;
extern NSString *RPL_SUMMONING;
extern NSString *RPL_INVITELIST;
extern NSString *RPL_ENDOFINVITELIST;
extern NSString *RPL_EXCEPTLIST;
extern NSString *RPL_ENDOFEXCEPTLIST;
extern NSString *RPL_VERSION;
extern NSString *RPL_WHOREPLY;
extern NSString *RPL_ENDOFWHO;
extern NSString *RPL_NAMREPLY;
extern NSString *RPL_ENDOFNAMES;
extern NSString *RPL_LINKS;
extern NSString *RPL_ENDOFLINKS;
extern NSString *RPL_BANLIST;
extern NSString *RPL_ENDOFBANLIST;
extern NSString *RPL_INFO;
extern NSString *RPL_ENDOFINFO;
extern NSString *RPL_MOTDSTART;
extern NSString *RPL_MOTD;
extern NSString *RPL_ENDOFMOTD;
extern NSString *RPL_YOUREOPER;
extern NSString *RPL_REHASHING;
extern NSString *RPL_YOURESERVICE;
extern NSString *RPL_TIME;
extern NSString *RPL_USERSSTART;
extern NSString *RPL_USERS;
extern NSString *RPL_ENDOFUSERS;
extern NSString *RPL_NOUSERS;
extern NSString *RPL_TRACELINK;
extern NSString *RPL_TRACECONNECTING;
extern NSString *RPL_TRACEHANDSHAKE;
extern NSString *RPL_TRACEUNKNOWN;
extern NSString *RPL_TRACEOPERATOR;
extern NSString *RPL_TRACEUSER;
extern NSString *RPL_TRACESERVER;
extern NSString *RPL_TRACESERVICE;
extern NSString *RPL_TRACENEWTYPE;
extern NSString *RPL_TRACECLASS;
extern NSString *RPL_TRACERECONNECT;
extern NSString *RPL_TRACELOG;
extern NSString *RPL_TRACEEND;
extern NSString *RPL_STATSLINKINFO;
extern NSString *RPL_STATSCOMMANDS;
extern NSString *RPL_ENDOFSTATS;
extern NSString *RPL_STATSUPTIME;
extern NSString *RPL_STATSOLINE;
extern NSString *RPL_UMODEIS;
extern NSString *RPL_SERVLIST;
extern NSString *RPL_SERVLISTEND;
extern NSString *RPL_LUSERCLIENT;
extern NSString *RPL_LUSEROP;
extern NSString *RPL_LUSERUNKNOWN;
extern NSString *RPL_LUSERCHANNELS;
extern NSString *RPL_LUSERME;
extern NSString *RPL_ADMINME;
extern NSString *RPL_ADMINLOC1;
extern NSString *RPL_ADMINLOC2;
extern NSString *RPL_ADMINEMAIL;
extern NSString *RPL_TRYAGAIN;
extern NSString *ERR_NOSUCHNICK;
extern NSString *ERR_NOSUCHSERVER;
extern NSString *ERR_NOSUCHCHANNEL;
extern NSString *ERR_CANNOTSENDTOCHAN;
extern NSString *ERR_TOOMANYCHANNELS;
extern NSString *ERR_WASNOSUCHNICK;
extern NSString *ERR_TOOMANYTARGETS;
extern NSString *ERR_NOSUCHSERVICE;
extern NSString *ERR_NOORIGIN;
extern NSString *ERR_NORECIPIENT;
extern NSString *ERR_NOTEXTTOSEND;
extern NSString *ERR_NOTOPLEVEL;
extern NSString *ERR_WILDTOPLEVEL;
extern NSString *ERR_BADMASK;
extern NSString *ERR_UNKNOWNCOMMAND;
extern NSString *ERR_NOMOTD;
extern NSString *ERR_NOADMININFO;
extern NSString *ERR_FILEERROR;
extern NSString *ERR_NONICKNAMEGIVEN;
extern NSString *ERR_ERRONEUSNICKNAME;
extern NSString *ERR_NICKNAMEINUSE;
extern NSString *ERR_NICKCOLLISION;
extern NSString *ERR_UNAVAILRESOURCE;
extern NSString *ERR_USERNOTINCHANNEL;
extern NSString *ERR_NOTONCHANNEL;
extern NSString *ERR_USERONCHANNEL;
extern NSString *ERR_NOLOGIN;
extern NSString *ERR_SUMMONDISABLED;
extern NSString *ERR_USERSDISABLED;
extern NSString *ERR_NOTREGISTERED;
extern NSString *ERR_NEEDMOREPARAMS;
extern NSString *ERR_ALREADYREGISTRED;
extern NSString *ERR_NOPERMFORHOST;
extern NSString *ERR_PASSWDMISMATCH;
extern NSString *ERR_YOUREBANNEDCREEP;
extern NSString *ERR_YOUWILLBEBANNED;
extern NSString *ERR_KEYSET;
extern NSString *ERR_CHANNELISFULL;
extern NSString *ERR_UNKNOWNMODE;
extern NSString *ERR_INVITEONLYCHAN;
extern NSString *ERR_BANNEDFROMCHAN;
extern NSString *ERR_BADCHANNELKEY;
extern NSString *ERR_BADCHANMASK;
extern NSString *ERR_NOCHANMODES;
extern NSString *ERR_BANLISTFULL;
extern NSString *ERR_NOPRIVILEGES;
extern NSString *ERR_CHANOPRIVSNEEDED;
extern NSString *ERR_CANTKILLSERVER;
extern NSString *ERR_RESTRICTED;
extern NSString *ERR_UNIQOPPRIVSNEEDED;
extern NSString *ERR_NOOPERHOST;
extern NSString *ERR_UMODEUNKNOWNFLAG;
extern NSString *ERR_USERSDONTMATCH;
extern NSString *RPL_SERVICEINFO;
extern NSString *RPL_ENDOFSERVICES;
extern NSString *RPL_SERVICE;
extern NSString *RPL_NONE;
extern NSString *RPL_WHOISCHANOP;
extern NSString *RPL_KILLDONE;
extern NSString *RPL_CLOSING;
extern NSString *RPL_CLOSEEND;
extern NSString *RPL_INFOSTART;
extern NSString *RPL_MYPORTIS;
extern NSString *RPL_STATSCLINE;
extern NSString *RPL_STATSNLINE;
extern NSString *RPL_STATSILINE;
extern NSString *RPL_STATSKLINE;
extern NSString *RPL_STATSQLINE;
extern NSString *RPL_STATSYLINE;
extern NSString *RPL_STATSVLINE;
extern NSString *RPL_STATSLLINE;
extern NSString *RPL_STATSHLINE;
extern NSString *RPL_STATSSLINE;
extern NSString *RPL_STATSPING;
extern NSString *RPL_STATSBLINE;
extern NSString *RPL_STATSDLINE;
extern NSString *ERR_NOSERVICEHOST;
