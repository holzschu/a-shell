#include <stddef.h>
#include <string.h>
#include <tree_sitter/api.h>

// Keep the stock parsers in the framework binary: iOS frameworks cannot embed
// independently loaded executable files as resources.
#define DECLARE(lang) extern const TSLanguage *tree_sitter_##lang(void)
DECLARE(c);
DECLARE(lua);
DECLARE(markdown);
DECLARE(markdown_inline);
DECLARE(query);
DECLARE(vim);
DECLARE(vimdoc);
#undef DECLARE

const TSLanguage *nvim_port_builtin_parser(const char *name) {
#define MATCH(lang) if (strcmp(name, #lang) == 0) return tree_sitter_##lang()
    MATCH(c);
    MATCH(lua);
    MATCH(markdown);
    MATCH(markdown_inline);
    MATCH(query);
    MATCH(vim);
    MATCH(vimdoc);
#undef MATCH
    return NULL;
}
