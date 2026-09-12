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

fixen() {
    local input

    if [ -n "$1" ]; then
        input="$*"
    else
        local clip
        clip=$(pbpaste)
        echo "Press Enter to use clipboard text, or type your own sentence and press Enter:"
        if [ -n "$clip" ]; then
            echo "Clipboard: $clip"
        fi
        read "typed?> "
        if [ -n "$typed" ]; then
            input="$typed"
        else
            input="$clip"
        fi
    fi

    if [ -z "$input" ]; then
        echo "No text provided."
        return 1
    fi

    echo ""
    echo "Fixing:"
    echo "$input"
    echo ""

    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': 'You are a helpful IT support person. Correct the grammar and rewrite the text in a concise, friendly, professional tone suitable for workplace communication. Respond with ONLY the corrected version, nothing else. No explanation, no notes, no quotation marks around it.'},
        {'role': 'user', 'content': sys.argv[1]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$input")

    local response
    response=$(curl -s -m 30 "$DGX_ENDPOINT/chat/completions" \
        -H "Authorization: Bearer $DGX_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if [ -z "$response" ]; then
        echo "Error: no response from DGX endpoint. Check that it is reachable and try again."
        return 1
    fi

    local result
    result=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'].strip())
except Exception as e:
    print('PARSE_ERROR', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$result" ]; then
        echo "Error: could not parse a valid response from the model."
        echo "Raw response was:"
        echo "$response"
        return 1
    fi

    echo "Fixed:"
    echo "$result"
    echo "$result" | pbcopy
    echo ""
    echo "(copied to clipboard, paste with Cmd+V)"
}
