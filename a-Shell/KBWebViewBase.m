//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


#import "KBWebViewBase.h"
#import <objc/runtime.h>

@interface KBWebViewBase (WKScriptMessageHandler) <WKScriptMessageHandler>

- (void)_blink_updateTextInputTraits:(id <UITextInputTraits>)traits;

@end

@interface UIView (Foo)

- (void)_blink_updateTextInputTraits:(id <UITextInputTraits>)traits;

@end

@implementation UIView (Foo)

- (void)_blink_updateTextInputTraits:(id <UITextInputTraits>)traits {
  UIView * mayBeUs = [[self superview] superview];
  if ([mayBeUs isKindOfClass:[KBWebViewBase class]]) {
    KBWebViewBase * base = (KBWebViewBase *)mayBeUs;
    [base _blink_updateTextInputTraits:traits];
  }
}

@end

@implementation KBWebViewBase

+ (void)load {
  NSString * clsName = [@[
      @"W",//e
      @"K",//now this is not
      @"C", //ool.
      @"ontent", // but it is only way to fix WkWeb
      @"View", // our radars: FB9628179, https://bugs.webkit.org/show_bug.cgi?id=230360
  ] componentsJoinedByString:@""];


  Class cls = NSClassFromString(clsName);
  IMP iml = class_getMethodImplementation(cls, NSSelectorFromString(@"_blink_updateTextInputTraits:"));

  class_replaceMethod(cls, NSSelectorFromString(@"_updateTextInputTraits:"), iml, nil);

  SEL selector = sel_getUid("_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:");
  Method method = class_getInstanceMethod(cls, selector);
  IMP original = method_getImplementation(method);
  IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
    ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3, arg4);
  });
  method_setImplementation(method, override);
}

- (void)_blink_updateTextInputTraits:(id <UITextInputTraits>)traits {
  traits.smartDashesType = UITextSmartDashesTypeNo;
  traits.smartQuotesType = UITextSmartQuotesTypeNo;
  traits.autocorrectionType = UITextAutocorrectionTypeNo;
  traits.autocapitalizationType = UITextAutocapitalizationTypeNone;
  traits.spellCheckingType = UITextSpellCheckingTypeNo;
}

@end
