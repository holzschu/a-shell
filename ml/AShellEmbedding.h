#pragma once
#import <Foundation/Foundation.h>

// Objective-C consumers exercise the Swift runtime through these C entry points.
NSDictionary *ASMLEmbeddingTokenize(NSString *modelID, NSDictionary *tokenizer, NSDictionary *request, NSError **error);
NSDictionary *ASMLEmbeddingPredict(NSDictionary *models, NSDictionary *request, NSError *(^check)(void), void (^progress)(NSUInteger), NSError **error);
