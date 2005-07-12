/***************************************************************************
                                conversions.m
                          -------------------
    begin                : Sun Dec 21 01:37:22 CST 2003
    copyright            : (C) 2003 by Andy Ruder
    email                : aeruder@ksu.edu
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
#import "testsuite.h"

#import <Foundation/Foundation.h>

int main(void)
{
	CREATE_AUTORELEASE_POOL(apr);
	TCPSystem *system;
	NSEnumerator *iter;
	id object;
	uint32_t num;
	NSDictionary *dict;
	
	system = [TCPSystem sharedInstance];

	dict = 
	  [NSDictionary dictionaryWithObjectsAndKeys:
	  @"0x4466dc75", @"68.102.220.117",
	  @"0x7f000001", @"127.0.0.1",
	  @"0xffffffff", @"255.255.255.255",
	  nil];

	iter = [dict keyEnumerator];

	while ((object = [iter nextObject]))
	{
		id val;

		val = [dict objectForKey: object];
		num = 0;
		[system hostOrderInteger: &num fromHost: [NSHost hostWithAddress: object]];
		testEqual(@"Host order",
		  [NSString stringWithFormat:@"0x%llx", (long long unsigned)num], val);
	}

	dict = 
	  [NSDictionary dictionaryWithObjectsAndKeys:
	  @"0x75dc6644", @"68.102.220.117", 
	  @"0x100007f", @"127.0.0.1",
	  @"0xffffffff", @"255.255.255.255",
	  nil];

	iter = [dict keyEnumerator];

	while ((object = [iter nextObject]))
	{
		id val;

		val = [dict objectForKey: object];
		num = 0;
		[system networkOrderInteger: &num fromHost: [NSHost hostWithAddress: object]];
		testEqual(@"Network order",
		  [NSString stringWithFormat:@"0x%llx", (long long unsigned)num], val);
	}

	RELEASE(apr);
	
	return 0;
}
