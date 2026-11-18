#pragma once
#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

// Fixed package ABI: sequential batches of 1x128 tokens, native pooling and L2 normalization.
BOOL ASMLEmbeddingID(NSString *modelID);
NSDictionary *ASMLEmbeddingTokenize(NSString *modelID, NSDictionary *tokenizer, NSDictionary *request, NSError **error);
BOOL ASMLEmbeddingPlan(NSDictionary *plan, NSError **error);
NSDictionary *ASMLEmbeddingLoad(NSURL *compiled, NSURL *content, NSDictionary *plan, MLComputeUnits units, NSError **error);
NSDictionary *ASMLEmbeddingPredict(NSDictionary *models, NSDictionary *request, NSError *(^check)(void), void (^progress)(NSUInteger), NSError **error);
BOOL ASMLEmbeddingValidate(NSURL *compiled, NSURL *content, NSDictionary *plan, NSError *(^check)(void), NSError **error);
