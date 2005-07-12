/***************************************************************************
                                testsuite.h
                          -------------------
    begin                : Mon Jul 11 20:01:57 CDT 2005
    copyright            : (C) 2005 by Andrew Ruder
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

#import <Foundation/NSString.h>
#include <stdio.h>
#include <stdlib.h>

#define testWrite(format, args...) fprintf(stdout, "%s", \
   [[NSString stringWithFormat: \
   (format), ## args ] cString])

inline BOOL PASS(NSString *desc) {
	testWrite(@"PASS: %@\n" , desc);
	return YES;
}

inline BOOL FAIL(NSString *desc) {
	testWrite(@"FAIL: %@\n" , desc);
	return NO;
}

#define testTrue(desc, expression) \
	(expression) ? PASS(desc) : FAIL(desc);
	
#define testFalse(desc, expression) \
	(expression) ? FAIL(desc) : PASS(desc);

inline BOOL testEqual(NSString *desc, id o1, id o2) {
	desc = [NSString stringWithFormat: @"%@: %@ == %@", desc, o1, o2];
	return [o1 isEqual: o2] ? PASS(desc) : FAIL(desc);
}

inline BOOL testNotEqual(NSString *desc, id o1, id o2) {
	desc = [NSString stringWithFormat: @"%@: %@ == %@", desc, o1, o2];
	return (![o1 isEqual: o2]) ? PASS(desc) : FAIL(desc);
}

