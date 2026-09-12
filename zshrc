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
    local OPTIND opt tone="it"
    while getopts "fce" opt; do
        case $opt in
            f) tone="formal" ;;
            c) tone="casual" ;;
            e) tone="empathetic" ;;
        esac
    done
    shift $((OPTIND - 1))

    local system_prompt
    case $tone in
        formal)
            system_prompt="Correct the grammar and rewrite the text in a formal, polished, business-appropriate tone. Respond with ONLY the corrected version, nothing else."
            ;;
        casual)
            system_prompt="Correct the grammar and rewrite the text in a relaxed, casual, friendly tone, like texting a friend. Respond with ONLY the corrected version, nothing else."
            ;;
        empathetic)
            system_prompt="Rewrite the given text, keeping the exact same speaker, meaning, and intent. Correct the grammar and adjust the tone to sound calm, patient, and upbeat. Do not switch perspective, do not respond to the text or offer help as if you are someone else, and do not add new instructions or attempt to solve any problem mentioned, only rewrite what was said in a calmer and more patient way. Do not use emoji. Respond with ONLY the corrected version, nothing else."
            ;;
        *)
            system_prompt="You are a helpful IT support person. Correct the grammar and rewrite the text in a concise, friendly, professional tone suitable for workplace communication. Respond with ONLY the corrected version, nothing else."
            ;;
    esac

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
    echo "Fixing ($tone tone):"
    echo "$input"
    echo ""

    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': sys.argv[2]},
        {'role': 'user', 'content': sys.argv[1]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$input" "$system_prompt")

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
    result=$(printf '%s' "$response" | python3 -c "
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
    echo ""
    echo "Changes:"
    python3 -c "
import difflib, sys
original = sys.argv[1].split()
fixed = sys.argv[2].split()
sm = difflib.SequenceMatcher(None, original, fixed)
RED = chr(27) + '[31m'
GREEN = chr(27) + '[32m'
RESET = chr(27) + '[0m'
out = []
for tag, i1, i2, j1, j2 in sm.get_opcodes():
    if tag == 'equal':
        out.extend(fixed[j1:j2])
    elif tag == 'replace':
        out.append(RED + ' '.join(original[i1:i2]) + RESET)
        out.append(GREEN + ' '.join(fixed[j1:j2]) + RESET)
    elif tag == 'delete':
        out.append(RED + ' '.join(original[i1:i2]) + RESET)
    elif tag == 'insert':
        out.append(GREEN + ' '.join(fixed[j1:j2]) + RESET)
print(' '.join(out))
" "$input" "$result"
    echo ""
    echo "$result" | pbcopy
    echo "(copied to clipboard, paste with Cmd+V)"
}
