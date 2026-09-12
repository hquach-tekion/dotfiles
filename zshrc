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
    local model="${1:-$DGX_MODEL}"

    echo "DGX Spark Endpoint"
    echo "-------------------"
    echo "Endpoint: $DGX_ENDPOINT"
    echo "Model:    $model"
    echo "Token:    $DGX_API_KEY"
    echo ""
    echo "Quick test:"
    echo "curl \$DGX_ENDPOINT/chat/completions \\"
    echo "  -H \"Authorization: Bearer \$DGX_API_KEY\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'"
    echo ""
    echo "List all models currently loaded:"
    echo "curl \$DGX_ENDPOINT/models -H \"Authorization: Bearer \$DGX_API_KEY\""
}

dgx-models() {
    curl -s "$DGX_ENDPOINT/models" -H "Authorization: Bearer $DGX_API_KEY" | nu --stdin -c "from json | get data | select id"
}


aider-dgx() {
    OPENAI_API_BASE=$DGX_ENDPOINT OPENAI_API_KEY=$DGX_API_KEY aider --model openai/$DGX_MODEL --model-settings-file ~/.aider.model.settings.yml "$@"
}


export SSL_CERT_FILE=~/.netskope-combined-ca.pem

ai() {
    local prompt="$*"
    if [ -z "$prompt" ]; then
        echo "Usage: ai <describe what you want to do>"
        return 1
    fi
    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': 'You are a shell command generator for macOS zsh. Given a description, respond with ONLY the exact shell command. No explanation. No markdown. No backticks.'},
        {'role': 'user', 'content': sys.argv[1]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$prompt")

    curl -s "$DGX_ENDPOINT/chat/completions" \
        -H "Authorization: Bearer $DGX_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['choices'][0]['message']['content'].strip())
"
}

explain() {
    local cmd="$*"
    if [ -z "$cmd" ]; then
        echo "Usage: explain <command to explain>"
        return 1
    fi
    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': 'You explain shell commands in plain English. Be concise, a few sentences max. Mention any risky or destructive flags explicitly.'},
        {'role': 'user', 'content': sys.argv[1]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$cmd")

    curl -s "$DGX_ENDPOINT/chat/completions" \
        -H "Authorization: Bearer $DGX_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['choices'][0]['message']['content'].strip())
"
}
