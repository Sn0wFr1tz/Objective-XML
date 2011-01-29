/* MPWObject.m Copyright (c) 1998-2000 by Marcel Weiher, All Rights Reserved.


Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

	Redistributions of source code must retain the above copyright
	notice, this list of conditions and the following disclaimer.

	Redistributions in binary form must reproduce the above copyright
	notice, this list of conditions and the following disclaimer in
	the documentation and/or other materials provided with the distribution.

	Neither the name Marcel Weiher nor the names of contributors may
	be used to endorse or promote products derived from this software
	without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
THE POSSIBILITY OF SUCH DAMAGE.

*/


//#define LOCKING

#import "MPWObject.h"
#import <Foundation/Foundation.h>

#undef Darwin

#ifdef Rhapsody
#define CTHREADS 1
#endif
#ifdef GNUSTEP
#if !(defined(WIN32) || defined(_WIN32))
#define PTHREADS 1
#endif
#endif

#ifdef Darwin
#define CoreFoundation 1
#endif

#if CTHREADS
#import <mach/cthreads.h>
//int debug;
static mutex_t retain_lock=NULL;
#define LOCK(l)	if ( l != NULL ) mutex_lock(l)
#define UNLOCK(l) if ( l != NULL ) mutex_unlock(l)
#define INIT_LOCK(l)	if ( l == NULL ) { l = mutex_alloc(); }

#elif PTHREADS
#import <pthread.h>
#warning ---- pthreads ---
static pthread_mutex_t* retain_lock=NULL;
static pthread_mutex_t _the_lock;
#define LOCK(l)	if ( l != NULL ) pthread_mutex_lock(l)
#define UNLOCK(l) if ( l != NULL ) pthread_mutex_unlock(l)
#define INIT_LOCK(l)	if ( l == NULL ) { l = &_the_lock; pthread_mutex_init(l,NULL); }
#elif CoreFoundation

#include "SpinLocks.h"
#warning ---- spinlocks ---
static unsigned int *retain_lock=NULL;
static unsigned int _the_lock=0;
#ifndef _CFSpinLock
extern void __CFSpinLock( unsigned int *lock );
extern void __CFSpinUnlock( unsigned int *lock );
#endif
#define LOCK(l)	if ( l != NULL ) __CFSpinLock(l)
#define UNLOCK(l) if ( l != NULL ) __CFSpinUnlock(l)
#define INIT_LOCK(l)	if ( l == NULL ) { l = &_the_lock; _the_lock=0; }

#else
//#error no locking primitive!
#define LOCK(l)
#define UNLOCK(l)
#define INIT_LOCK(l)
#include <libkern/OSAtomic.h>
#define INCREMENT( var )   (OSAtomicIncrement32(&var))
#define DECREMENT( var )   (OSAtomicDecrement32(&var))

#endif

//#warning retainMPWObject
static int _collecting=NO;

id retainMPWObject( MPWObject *obj )
{
	if ( !_collecting ) {
		LOCK(retain_lock);
		INCREMENT( obj->_retainCount );
		UNLOCK(retain_lock);
	}
    return obj;
}
void retainMPWObjects( MPWObject **objs, unsigned count )
{
    int i;
	if ( !_collecting ) {
		LOCK(retain_lock);
		for (i=0;i<count;i++) {
			if ( objs[i] ) {
				INCREMENT( objs[i]->_retainCount );
			}
		}
	}
    UNLOCK(retain_lock);
}

void releaseMPWObject( MPWObject *obj )
{
    if ( obj && !_collecting ) {
        LOCK(retain_lock);
        DECREMENT( obj->_retainCount);
        UNLOCK(retain_lock);
        if ( obj->_retainCount <0 ) {
            [obj dealloc];
        }
    }

}

void releaseMPWObjects( MPWObject **objs, unsigned count )
{
    if ( objs && !_collecting ) {
		int i;
		LOCK(retain_lock);
		for (i=0;i<count;i++) {
			if ( objs[i] ) {
				DECREMENT( objs[i]->_retainCount);
				if ( objs[i]->_retainCount < 0 ) {
					UNLOCK(retain_lock);
					[objs[i] dealloc];
					LOCK(retain_lock);
				}
			}
		}
		UNLOCK(retain_lock);
	}
}




@implementation MPWObject
/*"
     Provides a base object when fast reference counting is needed.
"*/


+(void)initialize
{
    static BOOL inited=NO;
    if (!inited) {
        [(NSNotificationCenter*)[NSNotificationCenter defaultCenter]
                     addObserver:self
                        selector:@selector(initializeThreaded)
                            name:NSWillBecomeMultiThreadedNotification
                          object:nil];
		_collecting=IS_OBJC_GC_ON;
        inited=YES;
    }
}

+(void)initializeThreaded
{
    INIT_LOCK( retain_lock );
}

+ alloc
{
    return (MPWObject *)NSAllocateObject(self, 0, NULL);
}

+ allocWithZone:(NSZone *)zone
{
    return (MPWObject *)NSAllocateObject(self, 0, zone);
}

- retain
{
    return retainMPWObject( self );
}

- (NSUInteger)retainCount
{
    return _retainCount+1;
}

- (oneway void)release
{
    releaseMPWObject(self);
}

-(NSString*)copyrightString
{
    return @"Copyright 1998-2008 by Marcel Weiher, All Rights Reserved.";
}

@end

#ifndef RELEASE

@implementation MPWObject(testing)

+(void)retaintCountAfterAlloc
{
    id mpwobj=[[MPWObject alloc] init];
    id nsobj=[[NSObject alloc] init];
    NSAssert2( [mpwobj retainCount] == [nsobj retainCount] ,@"retaincount not equal after alloc %d ,%d",[mpwobj retainCount],[nsobj retainCount]);
    [nsobj release];
    [mpwobj release];
}

+(void)retainCountSameAsNSObject
{
    id mpo=[[[MPWObject alloc] init] autorelease],nso=[[[NSObject alloc] init] autorelease];
    NSAssert2( [nso retainCount] ==
               [mpo retainCount], @"retainCount of NSObject (%d) not equal to MPWObject (%d)",[nso retainCount],[mpo retainCount]);
}

+testSelectors
{
	if ( !IS_OBJC_GC_ON ) {
		return [NSArray arrayWithObjects:
			@"retaintCountAfterAlloc",@"retainCountSameAsNSObject", nil];
	} else {
		return [NSArray array];
	}
}

@end

static int __globalCallDummy=0;
int ___crossModuleCallBenchmarkDoNothingFunction(int dummy1,int dummy2)
{
	__globalCallDummy++;
	return __globalCallDummy;
}

#endif
