# Keep the user's existing shell initialization intact.
export TERMI_USER_ZDOTDIR="${TERMI_ORIGINAL_ZDOTDIR:-$HOME}"
export ZDOTDIR="$TERMI_USER_ZDOTDIR"
[[ -f "$TERMI_USER_ZDOTDIR/.zshenv" ]] && source "$TERMI_USER_ZDOTDIR/.zshenv"
export TERMI_USER_ZDOTDIR="${ZDOTDIR:-$HOME}"
export ZDOTDIR="$TERMI_INTEGRATION_DIR"
