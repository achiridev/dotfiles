export COLORTERM=truecolor

typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git)

source $ZSH/oh-my-zsh.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias ls='eza --icons --group-directories-first --color=always --group'

[ -f ~/.config/zsh/private.zsh ] && source ~/.config/zsh/private.zsh

if [[ "$TERM" == "xterm-kitty" && -z "$FASTFETCH_SHOWN" ]]; then
    export FASTFETCH_SHOWN=1
    clear
    fastfetch
fi
