#import "AShellEmbedding.h"
#import <math.h>
#import <TargetConditionals.h>
#import <os/proc.h>

static BOOL fail(NSError **error, int code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"AShellML" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
BOOL ASMLEmbeddingID(NSString *modelID) { return [@[@"minilm-l6", @"qwen3-embedding-0.6b"] containsObject:modelID]; }
static BOOL qwen(NSString *modelID) { return [modelID isEqual:@"qwen3-embedding-0.6b"]; }
static NSString *scalar(uint32_t code) { return [[NSString alloc] initWithBytes:&code length:4 encoding:NSUTF32LittleEndianStringEncoding]; }
static NSArray *scalars(NSString *text) {
    NSData *data = [text dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
    const uint32_t *p = data.bytes; NSMutableArray *result = [NSMutableArray array];
    for (NSUInteger i = 0; i < data.length / 4; i++) [result addObject:scalar(p[i])];
    return result;
}
static NSArray *wordpiece(NSString *text, NSDictionary *vocab) {
    // Match tokenizers 0.21.4 / unicode_categories 0.1.1, whose Cf/Mn/P tables
    // equal Unicode 8.0. Cn is retained despite the dependency's broader comment.
    // Category ranges: https://www.unicode.org/Public/8.0.0/ucd/UnicodeData.txt
    // Pin these category properties independently of OS Unicode updates.
    static NSRegularExpression *control, *marks, *punctuation; static dispatch_once_t once;
    dispatch_once(&once, ^{
        control = [NSRegularExpression regularExpressionWithPattern:@"[\\u0000-\\u0008\\u000B-\\u000C\\u000E-\\u001F\\u007F-\\u009F\\u00AD\\u0600-\\u0605\\u061C\\u06DD\\u070F\\u180E\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u206F\\uE000-\\uF8FF\\uFEFF\\uFFF9-\\uFFFB\\x{110BD}\\x{1BCA0}-\\x{1BCA3}\\x{1D173}-\\x{1D17A}\\x{E0001}\\x{E0020}-\\x{E007F}\\x{F0000}-\\x{FFFFD}\\x{100000}-\\x{10FFFD}]" options:0 error:nil];
        marks = [NSRegularExpression regularExpressionWithPattern:@"[\\u0300-\\u036F\\u0483-\\u0487\\u0591-\\u05BD\\u05BF\\u05C1-\\u05C2\\u05C4-\\u05C5\\u05C7\\u0610-\\u061A\\u064B-\\u065F\\u0670\\u06D6-\\u06DC\\u06DF-\\u06E4\\u06E7-\\u06E8\\u06EA-\\u06ED\\u0711\\u0730-\\u074A\\u07A6-\\u07B0\\u07EB-\\u07F3\\u0816-\\u0819\\u081B-\\u0823\\u0825-\\u0827\\u0829-\\u082D\\u0859-\\u085B\\u08E3-\\u0902\\u093A\\u093C\\u0941-\\u0948\\u094D\\u0951-\\u0957\\u0962-\\u0963\\u0981\\u09BC\\u09C1-\\u09C4\\u09CD\\u09E2-\\u09E3\\u0A01-\\u0A02\\u0A3C\\u0A41-\\u0A42\\u0A47-\\u0A48\\u0A4B-\\u0A4D\\u0A51\\u0A70-\\u0A71\\u0A75\\u0A81-\\u0A82\\u0ABC\\u0AC1-\\u0AC5\\u0AC7-\\u0AC8\\u0ACD\\u0AE2-\\u0AE3\\u0B01\\u0B3C\\u0B3F\\u0B41-\\u0B44\\u0B4D\\u0B56\\u0B62-\\u0B63\\u0B82\\u0BC0\\u0BCD\\u0C00\\u0C3E-\\u0C40\\u0C46-\\u0C48\\u0C4A-\\u0C4D\\u0C55-\\u0C56\\u0C62-\\u0C63\\u0C81\\u0CBC\\u0CBF\\u0CC6\\u0CCC-\\u0CCD\\u0CE2-\\u0CE3\\u0D01\\u0D41-\\u0D44\\u0D4D\\u0D62-\\u0D63\\u0DCA\\u0DD2-\\u0DD4\\u0DD6\\u0E31\\u0E34-\\u0E3A\\u0E47-\\u0E4E\\u0EB1\\u0EB4-\\u0EB9\\u0EBB-\\u0EBC\\u0EC8-\\u0ECD\\u0F18-\\u0F19\\u0F35\\u0F37\\u0F39\\u0F71-\\u0F7E\\u0F80-\\u0F84\\u0F86-\\u0F87\\u0F8D-\\u0F97\\u0F99-\\u0FBC\\u0FC6\\u102D-\\u1030\\u1032-\\u1037\\u1039-\\u103A\\u103D-\\u103E\\u1058-\\u1059\\u105E-\\u1060\\u1071-\\u1074\\u1082\\u1085-\\u1086\\u108D\\u109D\\u135D-\\u135F\\u1712-\\u1714\\u1732-\\u1734\\u1752-\\u1753\\u1772-\\u1773\\u17B4-\\u17B5\\u17B7-\\u17BD\\u17C6\\u17C9-\\u17D3\\u17DD\\u180B-\\u180D\\u18A9\\u1920-\\u1922\\u1927-\\u1928\\u1932\\u1939-\\u193B\\u1A17-\\u1A18\\u1A1B\\u1A56\\u1A58-\\u1A5E\\u1A60\\u1A62\\u1A65-\\u1A6C\\u1A73-\\u1A7C\\u1A7F\\u1AB0-\\u1ABD\\u1B00-\\u1B03\\u1B34\\u1B36-\\u1B3A\\u1B3C\\u1B42\\u1B6B-\\u1B73\\u1B80-\\u1B81\\u1BA2-\\u1BA5\\u1BA8-\\u1BA9\\u1BAB-\\u1BAD\\u1BE6\\u1BE8-\\u1BE9\\u1BED\\u1BEF-\\u1BF1\\u1C2C-\\u1C33\\u1C36-\\u1C37\\u1CD0-\\u1CD2\\u1CD4-\\u1CE0\\u1CE2-\\u1CE8\\u1CED\\u1CF4\\u1CF8-\\u1CF9\\u1DC0-\\u1DF5\\u1DFC-\\u1DFF\\u20D0-\\u20DC\\u20E1\\u20E5-\\u20F0\\u2CEF-\\u2CF1\\u2D7F\\u2DE0-\\u2DFF\\u302A-\\u302D\\u3099-\\u309A\\uA66F\\uA674-\\uA67D\\uA69E-\\uA69F\\uA6F0-\\uA6F1\\uA802\\uA806\\uA80B\\uA825-\\uA826\\uA8C4\\uA8E0-\\uA8F1\\uA926-\\uA92D\\uA947-\\uA951\\uA980-\\uA982\\uA9B3\\uA9B6-\\uA9B9\\uA9BC\\uA9E5\\uAA29-\\uAA2E\\uAA31-\\uAA32\\uAA35-\\uAA36\\uAA43\\uAA4C\\uAA7C\\uAAB0\\uAAB2-\\uAAB4\\uAAB7-\\uAAB8\\uAABE-\\uAABF\\uAAC1\\uAAEC-\\uAAED\\uAAF6\\uABE5\\uABE8\\uABED\\uFB1E\\uFE00-\\uFE0F\\uFE20-\\uFE2F\\x{101FD}\\x{102E0}\\x{10376}-\\x{1037A}\\x{10A01}-\\x{10A03}\\x{10A05}-\\x{10A06}\\x{10A0C}-\\x{10A0F}\\x{10A38}-\\x{10A3A}\\x{10A3F}\\x{10AE5}-\\x{10AE6}\\x{11001}\\x{11038}-\\x{11046}\\x{1107F}-\\x{11081}\\x{110B3}-\\x{110B6}\\x{110B9}-\\x{110BA}\\x{11100}-\\x{11102}\\x{11127}-\\x{1112B}\\x{1112D}-\\x{11134}\\x{11173}\\x{11180}-\\x{11181}\\x{111B6}-\\x{111BE}\\x{111CA}-\\x{111CC}\\x{1122F}-\\x{11231}\\x{11234}\\x{11236}-\\x{11237}\\x{112DF}\\x{112E3}-\\x{112EA}\\x{11300}-\\x{11301}\\x{1133C}\\x{11340}\\x{11366}-\\x{1136C}\\x{11370}-\\x{11374}\\x{114B3}-\\x{114B8}\\x{114BA}\\x{114BF}-\\x{114C0}\\x{114C2}-\\x{114C3}\\x{115B2}-\\x{115B5}\\x{115BC}-\\x{115BD}\\x{115BF}-\\x{115C0}\\x{115DC}-\\x{115DD}\\x{11633}-\\x{1163A}\\x{1163D}\\x{1163F}-\\x{11640}\\x{116AB}\\x{116AD}\\x{116B0}-\\x{116B5}\\x{116B7}\\x{1171D}-\\x{1171F}\\x{11722}-\\x{11725}\\x{11727}-\\x{1172B}\\x{16AF0}-\\x{16AF4}\\x{16B30}-\\x{16B36}\\x{16F8F}-\\x{16F92}\\x{1BC9D}-\\x{1BC9E}\\x{1D167}-\\x{1D169}\\x{1D17B}-\\x{1D182}\\x{1D185}-\\x{1D18B}\\x{1D1AA}-\\x{1D1AD}\\x{1D242}-\\x{1D244}\\x{1DA00}-\\x{1DA36}\\x{1DA3B}-\\x{1DA6C}\\x{1DA75}\\x{1DA84}\\x{1DA9B}-\\x{1DA9F}\\x{1DAA1}-\\x{1DAAF}\\x{1E8D0}-\\x{1E8D6}\\x{E0100}-\\x{E01EF}]" options:0 error:nil];
        punctuation = [NSRegularExpression regularExpressionWithPattern:@"[\\u0021-\\u002F\\u003A-\\u0040\\u005B-\\u0060\\u007B-\\u007E\\u00A1\\u00A7\\u00AB\\u00B6-\\u00B7\\u00BB\\u00BF\\u037E\\u0387\\u055A-\\u055F\\u0589-\\u058A\\u05BE\\u05C0\\u05C3\\u05C6\\u05F3-\\u05F4\\u0609-\\u060A\\u060C-\\u060D\\u061B\\u061E-\\u061F\\u066A-\\u066D\\u06D4\\u0700-\\u070D\\u07F7-\\u07F9\\u0830-\\u083E\\u085E\\u0964-\\u0965\\u0970\\u0AF0\\u0DF4\\u0E4F\\u0E5A-\\u0E5B\\u0F04-\\u0F12\\u0F14\\u0F3A-\\u0F3D\\u0F85\\u0FD0-\\u0FD4\\u0FD9-\\u0FDA\\u104A-\\u104F\\u10FB\\u1360-\\u1368\\u1400\\u166D-\\u166E\\u169B-\\u169C\\u16EB-\\u16ED\\u1735-\\u1736\\u17D4-\\u17D6\\u17D8-\\u17DA\\u1800-\\u180A\\u1944-\\u1945\\u1A1E-\\u1A1F\\u1AA0-\\u1AA6\\u1AA8-\\u1AAD\\u1B5A-\\u1B60\\u1BFC-\\u1BFF\\u1C3B-\\u1C3F\\u1C7E-\\u1C7F\\u1CC0-\\u1CC7\\u1CD3\\u2010-\\u2027\\u2030-\\u2043\\u2045-\\u2051\\u2053-\\u205E\\u207D-\\u207E\\u208D-\\u208E\\u2308-\\u230B\\u2329-\\u232A\\u2768-\\u2775\\u27C5-\\u27C6\\u27E6-\\u27EF\\u2983-\\u2998\\u29D8-\\u29DB\\u29FC-\\u29FD\\u2CF9-\\u2CFC\\u2CFE-\\u2CFF\\u2D70\\u2E00-\\u2E2E\\u2E30-\\u2E42\\u3001-\\u3003\\u3008-\\u3011\\u3014-\\u301F\\u3030\\u303D\\u30A0\\u30FB\\uA4FE-\\uA4FF\\uA60D-\\uA60F\\uA673\\uA67E\\uA6F2-\\uA6F7\\uA874-\\uA877\\uA8CE-\\uA8CF\\uA8F8-\\uA8FA\\uA8FC\\uA92E-\\uA92F\\uA95F\\uA9C1-\\uA9CD\\uA9DE-\\uA9DF\\uAA5C-\\uAA5F\\uAADE-\\uAADF\\uAAF0-\\uAAF1\\uABEB\\uFD3E-\\uFD3F\\uFE10-\\uFE19\\uFE30-\\uFE52\\uFE54-\\uFE61\\uFE63\\uFE68\\uFE6A-\\uFE6B\\uFF01-\\uFF03\\uFF05-\\uFF0A\\uFF0C-\\uFF0F\\uFF1A-\\uFF1B\\uFF1F-\\uFF20\\uFF3B-\\uFF3D\\uFF3F\\uFF5B\\uFF5D\\uFF5F-\\uFF65\\x{10100}-\\x{10102}\\x{1039F}\\x{103D0}\\x{1056F}\\x{10857}\\x{1091F}\\x{1093F}\\x{10A50}-\\x{10A58}\\x{10A7F}\\x{10AF0}-\\x{10AF6}\\x{10B39}-\\x{10B3F}\\x{10B99}-\\x{10B9C}\\x{11047}-\\x{1104D}\\x{110BB}-\\x{110BC}\\x{110BE}-\\x{110C1}\\x{11140}-\\x{11143}\\x{11174}-\\x{11175}\\x{111C5}-\\x{111C9}\\x{111CD}\\x{111DB}\\x{111DD}-\\x{111DF}\\x{11238}-\\x{1123D}\\x{112A9}\\x{114C6}\\x{115C1}-\\x{115D7}\\x{11641}-\\x{11643}\\x{1173C}-\\x{1173E}\\x{12470}-\\x{12474}\\x{16A6E}-\\x{16A6F}\\x{16AF5}\\x{16B37}-\\x{16B3B}\\x{16B44}\\x{1BC9F}\\x{1DA87}-\\x{1DA8B}]" options:0 error:nil];
    });
    text = [control stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    NSMutableString *clean = [NSMutableString string];
    NSData *data = [text dataUsingEncoding:NSUTF32LittleEndianStringEncoding]; const uint32_t *codes = data.bytes;
    NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSUInteger i = 0; i < data.length / 4; i++) {
        uint32_t c = codes[i];
        if (!c || c == 0xfffd) continue;
        BOOL chinese = (c >= 0x4e00 && c <= 0x9fff) || (c >= 0x3400 && c <= 0x4dbf) || (c >= 0x20000 && c <= 0x2a6df) || (c >= 0x2a700 && c <= 0x2b73f) || (c >= 0x2b740 && c <= 0x2b81f) || (c >= 0x2b920 && c <= 0x2ceaf) || (c >= 0xf900 && c <= 0xfaff) || (c >= 0x2f800 && c <= 0x2fa1f);
        if (chinese) [clean appendFormat:@" %@ ", scalar(c)];
        else [clean appendString:[space longCharacterIsMember:c] ? @" " : scalar(c)];
    }
    NSString *normalized = clean.decomposedStringWithCanonicalMapping;
    normalized = [marks stringByReplacingMatchesInString:normalized options:0 range:NSMakeRange(0, normalized.length) withTemplate:@""];
    // Bert lowercases each scalar after stripping marks; whole-string lowercase
    // would turn word-final Greek capital sigma into a different WordPiece.
    NSMutableString *lowercase = [NSMutableString string];
    for (NSString *letter in scalars(normalized)) [lowercase appendString:letter.lowercaseString];
    normalized = lowercase;
    NSString *split = [punctuation stringByReplacingMatchesInString:normalized options:0 range:NSMakeRange(0, normalized.length) withTemplate:@" $0 "];
    NSMutableArray *ids = [NSMutableArray array];
    for (NSString *word in [split componentsSeparatedByCharactersInSet:space]) {
        if (!word.length) continue;
        NSArray *letters = scalars(word); NSMutableArray *pieces = [NSMutableArray array]; BOOL bad = letters.count > 100;
        NSUInteger start = 0;
        while (!bad && start < letters.count) {
            NSUInteger end = letters.count; NSNumber *found;
            for (; end > start; end--) {
                NSString *piece = [[letters subarrayWithRange:NSMakeRange(start, end - start)] componentsJoinedByString:@""];
                found = vocab[start ? [@"##" stringByAppendingString:piece] : piece];
                if (found) break;
            }
            if (!found) bad = YES; else { [pieces addObject:found]; start = end; }
        }
        if (bad) [ids addObject:@100]; else [ids addObjectsFromArray:pieces];
    }
    return ids;
}
static const void *retainPair(CFAllocatorRef allocator, const void *value) { (void)allocator; return CFRetain(value); }
static void releasePair(CFAllocatorRef allocator, const void *value) { (void)allocator; CFRelease(value); }
static CFComparisonResult comparePairs(const void *first, const void *second, void *context) {
    (void)context; NSDictionary *a = (__bridge NSDictionary *)first, *b = (__bridge NSDictionary *)second;
    NSComparisonResult order = [a[@"rank"] compare:b[@"rank"]];
    return (CFComparisonResult)(order == NSOrderedSame ? [a[@"left"] compare:b[@"left"]] : order);
}
static NSArray *bpe(NSString *text, NSDictionary *tokenizer, NSDictionary *prepared, NSError *(^check)(void), NSError **error) {
    NSRegularExpression *regex = prepared[@"regex"]; NSArray *byteMap = prepared[@"byte_map"]; NSDictionary *ranks = prepared[@"ranks"];
    NSMutableArray *ids = [NSMutableArray array]; NSDictionary *vocab = tokenizer[@"model"][@"vocab"];
    for (NSTextCheckingResult *match in [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)]) {
        NSError *stop = check ? check() : nil; if (stop) { if (error) *error = stop; return nil; }
        NSData *bytes = [[text substringWithRange:match.range] dataUsingEncoding:NSUTF8StringEncoding]; const uint8_t *p = bytes.bytes;
        NSMutableArray *pieces = [NSMutableArray array];
        for (NSUInteger i = 0; i < bytes.length; i++) [pieces addObject:byteMap[p[i]]];
        // Ranked neighbors in Core Foundation's heap avoid quadratic rescanning of
        // long pretokens. Versions discard pairs invalidated by neighboring merges.
        NSMutableData *links = [NSMutableData dataWithLength:3 * bytes.length * sizeof(NSUInteger)];
        NSUInteger *previous = links.mutableBytes, *next = previous + bytes.length, *versions = next + bytes.length;
        for (NSUInteger i = 0; i < bytes.length; i++) { previous[i] = i ? i - 1 : NSUIntegerMax; next[i] = i + 1; }
        CFBinaryHeapCallBacks callbacks = {0, retainPair, releasePair, NULL, comparePairs};
        CFBinaryHeapRef heap = CFBinaryHeapCreate(NULL, 0, &callbacks, NULL);
        if (!heap) { fail(error, 75, @"Cannot allocate tokenizer priority queue"); return nil; }
        void (^enqueue)(NSUInteger) = ^(NSUInteger left) {
            if (left >= bytes.length || next[left] >= bytes.length) return;
            NSUInteger right = next[left];
            NSNumber *rank = ranks[[NSString stringWithFormat:@"%@ %@", pieces[left], pieces[right]]];
            if (!rank) return;
            NSDictionary *pair = @{@"rank":rank, @"left":@(left), @"right":@(right), @"left_version":@(versions[left]), @"right_version":@(versions[right])};
            CFBinaryHeapAddValue(heap, (__bridge const void *)pair);
        };
        @try {
            for (NSUInteger i = 0; i + 1 < bytes.length; i++) {
                if (i % 256 == 0 && check && (stop = check())) { if (error) *error = stop; return nil; }
                enqueue(i);
            }
            NSUInteger steps = 0;
            while (CFBinaryHeapGetCount(heap)) {
                if (steps++ % 64 == 0 && check && (stop = check())) { if (error) *error = stop; return nil; }
                NSDictionary *pair = (__bridge NSDictionary *)CFBinaryHeapGetMinimum(heap);
                CFBinaryHeapRemoveMinimumValue(heap);
                NSUInteger left = [pair[@"left"] unsignedIntegerValue], right = [pair[@"right"] unsignedIntegerValue];
                if (next[left] != right || versions[left] != [pair[@"left_version"] unsignedIntegerValue] || versions[right] != [pair[@"right_version"] unsignedIntegerValue]) continue;
                pieces[left] = [pieces[left] stringByAppendingString:pieces[right]];
                versions[left]++; versions[right]++;
                next[left] = next[right];
                if (next[right] < bytes.length) previous[next[right]] = left;
                next[right] = NSUIntegerMax;
                enqueue(previous[left]); enqueue(left);
            }
        } @finally { CFRelease(heap); }
        for (NSUInteger i = 0; i < bytes.length; i = next[i]) {
            NSString *piece = pieces[i];
            if (!vocab[piece]) { fail(error, 2, @"Qwen vocabulary is incomplete"); return nil; } [ids addObject:vocab[piece]];
        }
    }
    return ids;
}
static NSDictionary *prepareBPE(NSDictionary *tokenizer, NSError **error) {
    NSString *pattern = tokenizer[@"pre_tokenizer"][@"pretokenizers"][0][@"pattern"][@"Regex"];
    if (![pattern isKindOfClass:NSString.class]) { fail(error, 2, @"Missing Qwen byte pretokenizer"); return nil; }
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:error];
    if (!regex) return nil;
    NSMutableArray *byteMap = [NSMutableArray array]; unsigned extra = 0;
    for (unsigned b = 0; b < 256; b++) [byteMap addObject:scalar((b >= 33 && b <= 126) || (b >= 161 && b <= 172) || b >= 174 ? b : 256 + extra++)];
    NSMutableDictionary *ranks = [NSMutableDictionary dictionary]; NSUInteger index = 0;
    for (id pair in tokenizer[@"model"][@"merges"]) { ranks[[pair isKindOfClass:NSArray.class] ? [pair componentsJoinedByString:@" "] : pair] = @(index++); }
    return @{@"ranks":ranks,@"regex":regex,@"byte_map":byteMap};
}
static NSDictionary *tokenize(NSString *modelID, NSDictionary *tokenizer, NSDictionary *prepared, NSDictionary *request, NSError *(^check)(void), NSError **error) {
    BOOL isQwen = qwen(modelID);
    if (!ASMLEmbeddingID(modelID) || ![tokenizer[@"model"][@"type"] isEqual:isQwen ? @"BPE" : @"WordPiece"] || ![request isKindOfClass:NSDictionary.class]) { fail(error, 2, @"Unsupported embedding tokenizer/request"); return nil; }
    for (NSString *key in request) if (![@[@"texts",@"instruction",@"truncate"] containsObject:key]) { fail(error, 2, @"Unknown embedding input field"); return nil; }
    NSArray *texts = request[@"texts"]; NSString *instruction = request[@"instruction"]; id truncate = request[@"truncate"];
    if (![texts isKindOfClass:NSArray.class] || texts.count < 1 || texts.count > 256 || (instruction && (!isQwen || ![instruction isKindOfClass:NSString.class] || !instruction.length || instruction.length > 1024)) || (truncate && CFGetTypeID((__bridge CFTypeRef)truncate) != CFBooleanGetTypeID())) { fail(error, 2, @"Require 1..256 texts, a boolean truncate and a Qwen-only instruction"); return nil; }
    NSMutableArray *batch = [NSMutableArray array], *masks = [NSMutableArray array], *counts = [NSMutableArray array], *truncated = [NSMutableArray array];
    NSMutableDictionary *special = [NSMutableDictionary dictionary];
    for (NSDictionary *added in tokenizer[@"added_tokens"]) special[added[@"content"]] = added[@"id"];
    NSArray *specials = [special.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) { return a.length > b.length ? NSOrderedAscending : a.length < b.length ? NSOrderedDescending : [a compare:b]; }];
    for (id input in texts) {
        NSError *stop = check ? check() : nil; if (stop) { if (error) *error = stop; return nil; }
        if (![input isKindOfClass:NSString.class] || ![input length] || [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 65536) { fail(error, 2, @"Text must be nonempty UTF-8, at most 65536 bytes"); return nil; }
        NSString *text = instruction ? [NSString stringWithFormat:@"Instruct: %@\nQuery:%@", instruction, input] : input;
        NSMutableArray *ids = [NSMutableArray array]; if (!isQwen) [ids addObject:@101];
        NSUInteger cursor = 0; NSMutableDictionary *occurrences = [NSMutableDictionary dictionary];
        while (cursor < text.length) {
            stop = check ? check() : nil; if (stop) { if (error) *error = stop; return nil; }
            NSRange earliest = NSMakeRange(NSNotFound, 0); NSString *selected;
            for (NSString *s in specials) {
                NSValue *cached = occurrences[s]; NSRange r = cached ? cached.rangeValue : NSMakeRange(0, 0);
                if (!cached || r.location < cursor) {
                    r = [text rangeOfString:s options:NSLiteralSearch range:NSMakeRange(cursor, text.length - cursor)];
                    occurrences[s] = [NSValue valueWithRange:r];
                }
                if (r.location < earliest.location) { earliest = r; selected = s; }
            }
            NSUInteger end = selected ? earliest.location : text.length;
            if (end > cursor) {
                NSString *part = [text substringWithRange:NSMakeRange(cursor, end - cursor)];
                // Qwen added tokens match raw input before NFC can compose their
                // trailing ">" with a combining mark and hide the token boundary.
                if (isQwen) part = part.precomposedStringWithCanonicalMapping;
                NSArray *pieces = isQwen ? bpe(part, tokenizer, prepared, check, error) : wordpiece(part, tokenizer[@"model"][@"vocab"]);
                if (!pieces) return nil; [ids addObjectsFromArray:pieces];
            }
            if (selected) [ids addObject:special[selected]];
            cursor = selected ? NSMaxRange(earliest) : text.length;
        }
        NSNumber *last = isQwen ? @151643 : @102; [ids addObject:last];
        NSUInteger original = ids.count;
        if (original > 128) {
            if (![truncate boolValue]) { fail(error, 2, @"Text exceeds 128 tokens; set truncate=true explicitly"); return nil; }
            [ids removeObjectsInRange:NSMakeRange(127, ids.count - 127)]; [ids addObject:last];
        }
        [counts addObject:@(ids.count)]; [truncated addObject:@(original > 128)];
        NSMutableArray *mask = [NSMutableArray array]; for (NSUInteger i = 0; i < ids.count; i++) [mask addObject:@1];
        while (ids.count < 128) { if (isQwen) { [ids insertObject:@151643 atIndex:0]; [mask insertObject:@0 atIndex:0]; } else { [ids addObject:@0]; [mask addObject:@0]; } }
        [batch addObject:ids]; [masks addObject:mask];
    }
    return @{@"ids":batch,@"mask":masks,@"token_counts":counts,@"truncated":truncated};
}
NSDictionary *ASMLEmbeddingTokenize(NSString *modelID, NSDictionary *tokenizer, NSDictionary *request, NSError **error) {
    NSDictionary *prepared = qwen(modelID) ? prepareBPE(tokenizer, error) : @{};
    return prepared ? tokenize(modelID, tokenizer, prepared, request, nil, error) : nil;
}

BOOL ASMLEmbeddingPlan(NSDictionary *p, NSError **error) {
    BOOL isQwen = qwen(p[@"model_id"]); NSUInteger width = isQwen ? 1024 : 384;
    // 2.5-GiB admission is scoped to the pinned mixed-FP16 graph; legacy profiles retain their budget.
    BOOL qwenFP16Budget = isQwen && [p[@"source_sha256"] isEqual:@"b46d02f0fd85253ae1647af28acb74f76665f5d7a75145187dd67fc8717f52db"] &&
        [p[@"memory_profile"][@"additional_peak_bytes"] isEqual:@(5ULL*1024*1024*1024/2)];
    BOOL valid = ASMLEmbeddingID(p[@"model_id"]) && [p[@"task"] isEqual:@"text-embedding"] && [p[@"adapter_version"] isEqual:@1] && [p[@"minimum_ios"] isEqual:@"18.0"] &&
        [p[@"source_revision"] isEqual:isQwen ? @"97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3" : @"1110a243fdf4706b3f48f1d95db1a4f5529b4d41"] &&
        [p[@"model"] isEqual:@"Embedding.mlpackage"] && [p[@"tokenizer"] isEqual:@"tokenizer.json"] && [p[@"decoder"] isEqual:@"l2-v1"] && [p[@"preprocessing"] isEqual:isQwen ? @"qwen3-last-token-v1" : @"minilm-masked-mean-v1"] &&
        [p[@"features"] isEqual:@{@"input_ids":@{@"dtype":@"int32",@"shape":@[@1,@128]},@"attention_mask":@{@"dtype":@"int32",@"shape":@[@1,@128]}}] &&
        [p[@"outputs"] isEqual:@{@"embedding":@{@"dtype":@"float32",@"shape":@[@(width)],@"normalized":@YES}}] &&
        [p[@"memory_profile"][@"kind"] isEqual:@"bounded-embedding-qualification"] && ([p[@"memory_profile"][@"additional_peak_bytes"] isEqual:@(isQwen ? 3ULL*1024*1024*1024 : 512ULL*1024*1024)] || qwenFP16Budget) &&
        [p[@"members"][@"tokenizer.json"][@"type"] isEqual:@"file"] && [p[@"members"][@"validation.json"][@"type"] isEqual:@"file"] && [p[@"validation"][@"input"] isEqual:@"validation.json"];
    valid = valid && [p[@"members"][@"tokenizer.json"][@"sha256"] isEqual:isQwen ? @"def76fb086971c7867b829c23a26261e38d9d74e02139253b38aeb9df8b4b50a" : @"be50c3628f2bf5bb5e3a7f17b1f74611b2561a3a27eeab05e5aa30f411572037"] && [p[@"members"][@"tokenizer.json"][@"bytes"] isEqual:isQwen ? @11423705 : @466247] && [p[@"members"][@"validation.json"][@"bytes"] unsignedLongLongValue] <= 1048576;
    return valid || fail(error, 2, @"Unsupported embedding package ABI/source/pooling/memory contract");
}
NSDictionary *ASMLEmbeddingLoad(NSURL *compiled, NSURL *content, NSDictionary *plan, MLComputeUnits units, NSError **error) {
    if (!ASMLEmbeddingPlan(plan, error)) return nil;
#if TARGET_OS_IPHONE
    size_t available = os_proc_available_memory();
    if (available < MAX(128ULL*1024*1024, available/5) + [plan[@"memory_profile"][@"additional_peak_bytes"] unsignedLongLongValue]) { fail(error, 75, @"Insufficient process headroom for embeddings"); return nil; }
#endif
    MLModelConfiguration *config = [MLModelConfiguration new]; config.computeUnits = units;
    MLModel *model = [MLModel modelWithContentsOfURL:compiled configuration:config error:error]; if (!model) return nil;
    NSDictionary *inputs = model.modelDescription.inputDescriptionsByName, *outputs = model.modelDescription.outputDescriptionsByName;
    if (inputs.count != 2 || outputs.count != 1) { fail(error, 2, @"Embedding graph feature count mismatch"); return nil; }
    for (NSString *key in @[@"input_ids", @"attention_mask"]) {
        MLFeatureDescription *f = inputs[key];
        if (f.type != MLFeatureTypeMultiArray || f.multiArrayConstraint.dataType != MLMultiArrayDataTypeInt32 || ![f.multiArrayConstraint.shape isEqual:@[@1,@128]]) { fail(error, 2, @"Embedding graph input mismatch"); return nil; }
    }
    MLFeatureDescription *out = outputs[@"hidden_states"];
    if (out.type != MLFeatureTypeMultiArray || out.multiArrayConstraint.dataType != MLMultiArrayDataTypeFloat32 || ![out.multiArrayConstraint.shape isEqual:@[@1,@128,@(qwen(plan[@"model_id"]) ? 1024 : 384)]]) { fail(error, 2, @"Embedding hidden-state shape/dtype mismatch"); return nil; }
    NSData *data = [NSData dataWithContentsOfURL:[content URLByAppendingPathComponent:@"tokenizer.json"] options:NSDataReadingMappedIfSafe error:error];
    NSDictionary *tokenizer = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:error] : nil;
    if (![tokenizer isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *prepared = qwen(plan[@"model_id"]) ? prepareBPE(tokenizer, error) : @{}; if (!prepared) return nil;
    return @{@"model":model,@"tokenizer":tokenizer,@"bpe":prepared,@"model_id":plan[@"model_id"]};
}
NSDictionary *ASMLEmbeddingPredict(NSDictionary *models, NSDictionary *request, NSError *(^check)(void), void (^progress)(NSUInteger), NSError **outError) {
    // Retain cancellation/errors beyond each row's pool before autoreleasing to
    // the caller. Returning a pool-local error caused a cancellation use-after-free.
    __block NSError *error;
    NSDictionary *result = ^NSDictionary *{
    error = check ? check() : nil; if (error) return nil;
    NSDictionary *tokens = tokenize(models[@"model_id"], models[@"tokenizer"], models[@"bpe"], request, check, &error); if (!tokens) return nil;
    NSMutableArray *vectors = [NSMutableArray array]; BOOL isQwen = qwen(models[@"model_id"]); NSUInteger width = isQwen ? 1024 : 384;
    for (NSUInteger row = 0; row < [tokens[@"ids"] count]; row++) { @autoreleasepool {
        NSError *stop = check ? check() : nil; if (stop) { error = stop; return nil; }
        NSMutableDictionary *features = [NSMutableDictionary dictionary];
        for (NSString *name in @[@"input_ids", @"attention_mask"]) {
            MLMultiArray *a = [[MLMultiArray alloc] initWithShape:@[@1,@128] dataType:MLMultiArrayDataTypeInt32 error:&error]; if (!a) return nil;
            NSArray *values = tokens[[name isEqual:@"input_ids"] ? @"ids" : @"mask"][row];
            for (NSUInteger i = 0; i < 128; i++) a[i] = values[i];
            features[name] = a;
        }
        MLDictionaryFeatureProvider *input = [[MLDictionaryFeatureProvider alloc] initWithDictionary:features error:&error];
        id<MLFeatureProvider> output = input ? [models[@"model"] predictionFromFeatures:input error:&error] : nil;
        if (!output) return nil;
        MLMultiArray *hidden = [output featureValueForName:@"hidden_states"].multiArrayValue;
        NSMutableArray *vector = [NSMutableArray array]; double norm = 0;
        for (NSUInteger d = 0; d < width; d++) {
            double value = 0;
            for (NSUInteger t = isQwen ? 127 : 0; t < 128; t++) if ([tokens[@"mask"][row][t] boolValue]) value += [hidden[@[@0,@(t),@(d)]] doubleValue];
            if (!isQwen) value /= [tokens[@"token_counts"][row] doubleValue];
            if (!isfinite(value)) { fail(&error, 2, @"Nonfinite embedding output"); return nil; }
            norm += value*value; [vector addObject:@(value)];
        }
        if (!isfinite(norm) || norm < 1e-24) { fail(&error, 2, @"Zero or nonfinite embedding norm"); return nil; }
        norm = sqrt(norm); for (NSUInteger d = 0; d < width; d++) vector[d] = @([vector[d] doubleValue]/norm);
        stop = check ? check() : nil; if (stop) { error = stop; return nil; }
        [vectors addObject:vector]; if (progress) progress(vectors.count);
    } }
    return @{@"embeddings":vectors,@"token_counts":tokens[@"token_counts"],@"truncated":tokens[@"truncated"],@"normalized":@YES,@"pooling":isQwen ? @"last-token" : @"masked-mean",@"dimension":@(width)};
    }();
    if (outError) *outError = error;
    return result;
}
BOOL ASMLEmbeddingValidate(NSURL *compiled, NSURL *content, NSDictionary *plan, NSError *(^check)(void), NSError **error) {
    NSError *stop = check ? check() : nil; if (stop) { if (error) *error = stop; return NO; }
    NSDictionary *models = ASMLEmbeddingLoad(compiled, content, plan, MLComputeUnitsCPUOnly, error); if (!models) return NO;
    NSData *data = [NSData dataWithContentsOfURL:[content URLByAppendingPathComponent:@"validation.json"] options:0 error:error];
    NSDictionary *fixture = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:error] : nil;
    if (![fixture isKindOfClass:NSDictionary.class] || ![fixture[@"expected"] isKindOfClass:NSArray.class]) return fail(error, 2, @"Invalid embedding known-answer fixture");
    NSDictionary *result = ASMLEmbeddingPredict(models, fixture[@"request"], check, nil, error); if (!result) return NO;
    NSArray *actual = result[@"embeddings"], *expected = fixture[@"expected"];
    if (actual.count != expected.count || !actual.count) return fail(error, 2, @"Embedding known-answer batch mismatch");
    for (NSUInteger row = 0; row < actual.count; row++) {
        if (![expected[row] isKindOfClass:NSArray.class] || [expected[row] count] != [actual[row] count]) return fail(error, 2, @"Embedding known-answer dimension mismatch");
        double dot = 0, norm = 0;
        for (NSUInteger d = 0; d < [actual[row] count]; d++) { id value = expected[row][d]; if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) return fail(error, 2, @"Nonfinite reference embedding"); dot += [actual[row][d] doubleValue] * [value doubleValue]; norm += [value doubleValue]*[value doubleValue]; }
        if (fabs(norm - 1) > 1e-4 || dot/sqrt(norm) < 0.99) return fail(error, 2, @"Embedding known-answer cosine below 0.99");
    }
    return YES;
}
