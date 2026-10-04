export COLORTERM=truecolor
export PATH="$HOME/.local/bin:$PATH"

typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git)

source $ZSH/oh-my-zsh.sh

export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias ls='eza --icons --group-directories-first --color=always --group'
alias cat='bat'

[ -f ~/.config/zsh/private.zsh ] && source ~/.config/zsh/private.zsh

if [[ "$TERM" == "xterm-kitty" && -z "$FASTFETCH_SHOWN" ]]; then
    export FASTFETCH_SHOWN=1
    clear
    # fastfetch
    fastfetch --logo none
fi

