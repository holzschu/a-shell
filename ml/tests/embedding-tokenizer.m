#import "../AShellEmbedding.h"
#import <Foundation/Foundation.h>
#include <unistd.h>

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 4) return 2;
        for (NSNumber *code in @[@130, @75]) {
            NSError *error;
            NSDictionary *result = ASMLEmbeddingPredict(nil, @{}, ^NSError *{
                return [NSError errorWithDomain:@"AShellML" code:code.intValue userInfo:nil];
            }, nil, &error);
            if (result || error.code != code.intValue) { fprintf(stderr, "Pre-tokenization cancellation lost: %ld\n", (long)error.code); return 1; }
        }
        NSDictionary *fixtures = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:nil];
        NSDictionary *tokenizer = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[3])] options:0 error:nil];
        NSDictionary *model = fixtures[@"models"][@(argv[2])];
        NSArray *cases = model[@"unicode_marks"] ? [model[@"cases"] arrayByAddingObject:model[@"unicode_marks"]] : model[@"cases"];
        if (!cases.count || !tokenizer) return 2;
        for (NSDictionary *entry in cases) {
            NSError *error;
            NSDictionary *actual = ASMLEmbeddingTokenize(@(argv[2]), tokenizer, entry[@"request"], &error);
            if (![actual[@"ids"] isEqual:entry[@"ids"]] || ![actual[@"mask"] isEqual:entry[@"mask"]]) {
                fprintf(stderr, "Tokenizer mismatch: %s\nactual=%s\n", entry.description.UTF8String, (actual ?: error).description.UTF8String); return 1;
            }
        }
        for (NSDictionary *bad in @[@{}, @{@"texts":@[]}, @{@"texts":@[@""]}, @{@"texts":@[@1]}, @{@"texts":@[@"hello"],@"truncate":@"yes"}, @{@"texts":@[@"hello"],@"unknown":@1}]) {
            NSError *error;
            if (ASMLEmbeddingTokenize(@(argv[2]), tokenizer, bad, &error) || error.code != 2) return 1;
        }
        NSError *error;
        NSString *overlength = [@"" stringByPaddingToLength:65537 withString:@"a" startingAtIndex:0];
        if (ASMLEmbeddingTokenize(@(argv[2]), tokenizer, @{@"texts":@[overlength]}, &error) || error.code != 2) return 1;
        if (model[@"long_letters"]) {
            NSDictionary *fixture = model[@"long_letters"];
            uint32_t state = [fixture[@"seed"] unsignedIntValue]; NSMutableString *text = [NSMutableString string];
            for (NSUInteger i = 0; i < [fixture[@"length"] unsignedIntegerValue]; i++) { state = state * 1664525U + 1013904223U; [text appendFormat:@"%c", 'a' + state % 26]; }
            double started = NSProcessInfo.processInfo.systemUptime;
            NSDictionary *actual = ASMLEmbeddingTokenize(@(argv[2]), tokenizer, @{@"texts":@[text], @"truncate":@YES}, &error);
            if (![actual[@"ids"] isEqual:@[fixture[@"ids"]]] || ![actual[@"mask"] isEqual:@[fixture[@"mask"]]] || NSProcessInfo.processInfo.systemUptime - started > 10) { fprintf(stderr, "Long-word tokenizer parity or 10-second budget failed\n"); return 1; }
        }
        for (NSDictionary *fixture in model[@"long_specials"] ? @[model[@"long_specials"], model[@"long_mixed"]] : @[]) {
            NSString *unit = fixture[@"unit"];
            NSString *text = [@"" stringByPaddingToLength:unit.length * [fixture[@"repeat"] unsignedIntegerValue] withString:unit startingAtIndex:0];
            NSMutableArray *texts = [NSMutableArray array], *ids = [NSMutableArray array], *masks = [NSMutableArray array];
            for (NSUInteger i = 0; i < [fixture[@"batch"] unsignedIntegerValue]; i++) { [texts addObject:text]; [ids addObject:fixture[@"ids"]]; [masks addObject:fixture[@"mask"]]; }
            double started = NSProcessInfo.processInfo.systemUptime;
            // Bound a reverted slow tokenizer even before its timing assertion returns.
            alarm(10);
            NSDictionary *actual = ASMLEmbeddingTokenize(@(argv[2]), tokenizer, @{@"texts":texts, @"truncate":@YES}, &error);
            alarm(0);
            if (![actual[@"ids"] isEqual:ids] || ![actual[@"mask"] isEqual:masks] || NSProcessInfo.processInfo.systemUptime - started > 5) { fprintf(stderr, "Special-token parity or 5-second budget failed\n"); return 1; }
        }
        printf("EMBEDDING_TOKENIZER_PASS %s %lu cases\n", argv[2], (unsigned long)cases.count);
    }
}
