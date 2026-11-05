export ZDOTDIR="$TERMI_USER_ZDOTDIR"
if [[ "$HISTFILE" == "$TERMI_INTEGRATION_DIR/"* ]]; then
    HISTFILE="$TERMI_USER_ZDOTDIR/.zsh_history"
fi
[[ -f "$TERMI_USER_ZDOTDIR/.zshrc" ]] && source "$TERMI_USER_ZDOTDIR/.zshrc"
export TERMI_USER_ZDOTDIR="${ZDOTDIR:-$HOME}"
export ZDOTDIR="$TERMI_INTEGRATION_DIR"
autoload -Uz add-zsh-hook
function _termi_directory() {
    local termi_dir="${PWD//\%/%25}"
    termi_dir="${termi_dir// /%20}"
    termi_dir="${termi_dir//#/%23}"
    termi_dir="${termi_dir//\?/%3F}"
    printf '\033]7;file://localhost%s\007' "$termi_dir"
}
add-zsh-hook precmd _termi_directory
if [[ "$TERMI_MINIMAL_PROMPT" == "1" ]]; then
    PROMPT=$'%F{#bfbeb7}%1~%f %F{#e5e4de}❯%f '
    RPROMPT=''
fi
if [[ "$TERMI_WELCOME" == "1" ]]; then
    printf '\033[1;38;2;229;228;222mtermi\033[0m\033[38;2;105;104;98m v1.0.0 · ⌘⇧P for commands\033[0m\n\n'
fi
