#####################################################################
# environment
#####################################################################

WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

TERM=dumb
PROMPT='% '
HISTSIZE=0
LANG=C
LISTMAX=1000

#####################################################################
# completions
#####################################################################

# Load user defined completions from .zsh/comp
if [ -d ~/.zsh/comp ]; then
        fpath=(~/.zsh/comp $fpath)
        autoload -U ~/.zsh/comp/*(:t)

        # reload completions
        r() {
                local f
                f=(~/.zsh/comp/*(.))
                unfunction $f:t 2> /dev/null
                autoload -U $f:t
        }
fi

zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:descriptions' format '%d'
zstyle ':completion:*:options' verbose yes
zstyle ':completion:*:values' verbose yes
zstyle ':completion:*:options' prefix-needed yes
# Use cache.
zstyle ':completion:*' use-cache true
# Ignore case.
zstyle ':completion:*' matcher-list \
        '' \
        'm:{a-z}={A-Z}' \
        'l:|=* r:|[.,_-]=* r:|=* m:{a-z}={A-Z}'
# Sudo completion.
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin \
        /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin
zstyle ':completion:*' menu select
zstyle ':completion:*' keep-prefix
zstyle ':completion:*' completer _oldlist _complete _match _ignored \
    _approximate _list _history

autoload -U compinit; compinit -d ~/.zcompdump

# Original completions.
compdef '_files -g "*.hs"' runhaskell
compdef _man w3mman
compdef _tex platex

# Search path in cd.
cdpath=($HOME)
# Search zsh functions.
fpath=($fpath ~/zsh/.zfunc)

#####################################################################
# options
#####################################################################

setopt no_always_last_prompt
setopt auto_list
setopt no_menu_complete
setopt no_auto_param_keys
setopt no_auto_param_slash
setopt no_auto_remove_slash
setopt complete_aliases
setopt no_list_ambiguous
setopt no_list_packed
setopt no_list_rows_first
setopt list_types

setopt no_beep
setopt print_eightbit
setopt extended_glob
