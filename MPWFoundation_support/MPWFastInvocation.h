//
//  MPWFastInvocation.h
//  MPWFoundation
//
//  Created by Marcel Weiher on 27/3/07.
//  Copyright 2007 Marcel Weiher. All rights reserved.
//

#import "MPWObject.h"
#import <Foundation/Foundation.h>

@interface MPWFastInvocation : MPWObject {
	SEL selector;
	id	target;
	int	numargs;
	id   args[10];
	id	result;
	IMP cached;
	BOOL useCaching;
	@public
	IMP  invokeFun;
}

#define	INVOKE( inv )	((inv)->invokeFun( (inv), @selector(resultOfInvoking))) 

-(void)invoke;
-resultOfInvoking;
-(void)setArgument:(void*)buffer atIndex:(NSInteger)argIndex;
-(void)setTarget:newTarget;
-(void)setSelector:(SEL)newSelector;
-resultOfInvokingWithArgs:(id*)newArgs count:(int)count;
-(void)setUseCaching:(BOOL)doCaching;
-(SEL)selector;
intAccessor_h(numargs, setNumargs)
@end

@interface NSInvocation(convenience)

-resultOfInvoking;

@end