/***************************************************************************
                                conversions.m
                          -------------------
    begin                : Sun Dec 21 01:37:22 CST 2003
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

#import <netclasses/NetTCP.h>
#import <netclasses/NetBase.h>

#import <Foundation/Foundation.h>

int main(void)
{
	NSString *string1;
	NSHost *host;
	NSAutoreleasePool *apr;
	TCPSystem *system;
	uint32_t num;
	
	char buffer[199];

	apr = [NSAutoreleasePool new];

	system = [TCPSystem sharedInstance];

	printf("Please enter a host: ");
	scanf("%200[^\n]%*c", buffer);
	
	string1 = [NSString stringWithCString: buffer];
	host = [NSHost hostWithName: string1];
	
	printf("Host: %s\n", [[host name] cString]);
	printf("Address: %s\n", [[host address] cString]);
	num = 0;
	[system hostOrderInteger: &num fromHost: host];
	printf("Host order integer: %Xl\n", num);
	num = 0;
	[system networkOrderInteger: &num fromHost: host];
	printf("Network order integer: %Xl\n", num);

	RELEASE(apr);
	
	return 0;
}
