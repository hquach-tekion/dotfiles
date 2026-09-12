eval "$(starship init zsh)"
alias ls="eza --icons=auto"
alias cat="bat"
eval "$(zoxide init zsh)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(atuin init zsh)"
fastfetch
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

[ -f ~/.dgx_secrets ] && source ~/.dgx_secrets

dgx-info() {
    echo "DGX Spark Endpoint"
    echo "-------------------"
    echo "Endpoint: $DGX_ENDPOINT"
    echo "Model:    $DGX_MODEL"
    echo "Token:    $DGX_API_KEY"
    echo ""
    echo "Quick test:"
    echo "curl \$DGX_ENDPOINT/models -H \"Authorization: Bearer \$DGX_API_KEY\""
}
