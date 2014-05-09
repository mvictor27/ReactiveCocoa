//
//  NSUserDefaults+RACSupport.m
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSUserDefaults+RACSupport.h"

#import "EXTScope.h"
#import "NSNotificationCenter+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACLifting.h"
#import "RACChannel.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"

@implementation NSUserDefaults (RACSupport)

- (RACSignal *)rac_objectsForKey:(NSString *)key {
	NSCParameterAssert(key != nil);

	RACSignal *keySampler = [[NSNotificationCenter.defaultCenter
		rac_addObserverForName:NSUserDefaultsDidChangeNotification object:self]
		mapReplace:key];
	
	return [[[self
		rac_liftSelector:@selector(objectForKey:) withSignals:keySampler, nil]
		distinctUntilChanged]
		setNameWithFormat:@"%@ -rac_objectsForKey: %@", self.rac_description, key];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSUserDefaults (RACSupportDeprecated)

- (RACChannelTerminal *)rac_channelTerminalForKey:(NSString *)key {
	RACChannel *channel = [RACChannel new];
	
	RACScheduler *scheduler = [RACScheduler scheduler];
	__block BOOL ignoreNextValue = NO;
	
	@weakify(self);
	[[[[[[[NSNotificationCenter.defaultCenter
		rac_addObserverForName:NSUserDefaultsDidChangeNotification object:self]
		map:^(id _) {
			@strongify(self);
			return [self objectForKey:key];
		}]
		startWith:[self objectForKey:key]]
		// Don't send values that were set on the other side of the terminal.
		filter:^ BOOL (id _) {
			if (RACScheduler.currentScheduler == scheduler && ignoreNextValue) {
				ignoreNextValue = NO;
				return NO;
			}
			return YES;
		}]
		distinctUntilChanged]
		takeUntil:self.rac_willDeallocSignal]
		subscribe:channel.leadingTerminal];
	
	[[channel.leadingTerminal
		deliverOn:scheduler]
		subscribeNext:^(id value) {
			@strongify(self);
			ignoreNextValue = YES;
			[self setObject:value forKey:key];
		}];
	
	return channel.followingTerminal;
}

@end

#pragma clang diagnostic pop
