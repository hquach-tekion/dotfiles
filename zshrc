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

    python3 -c "
import json, datetime, sys
entry = {
    'timestamp': datetime.datetime.now().isoformat(),
    'tone': sys.argv[1],
    'original': sys.argv[2],
    'fixed': sys.argv[3]
}
with open('$HOME/.fixen_history.log', 'a') as f:
    f.write(json.dumps(entry) + chr(10))
" "$tone" "$input" "$result"

    echo "$result" | pbcopy
    echo "(copied to clipboard, paste with Cmd+V)"
}

aicommit() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Not inside a git repository."
        return 1
    fi

    local diff
    diff=$(git diff --cached)

    if [ -z "$diff" ]; then
        echo "No staged changes. Stage files with 'git add' first."
        return 1
    fi

    echo "Generating commit message from staged diff..."

    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': 'You write concise git commit messages. Given a diff, respond with ONLY a commit message: a short imperative summary line under 72 characters, optionally followed by a blank line and a brief body explaining why, if needed. No markdown, no backticks, no explanation, just the commit message text.'},
        {'role': 'user', 'content': sys.argv[1]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$diff")

    local response
    response=$(curl -s -m 30 "$DGX_ENDPOINT/chat/completions" \
        -H "Authorization: Bearer $DGX_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if [ -z "$response" ]; then
        echo "Error: no response from DGX endpoint. Check that it is reachable and try again."
        return 1
    fi

    local message
    message=$(printf '%s' "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'].strip())
except Exception:
    print('PARSE_ERROR', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$message" ]; then
        echo "Error: could not parse a valid response from the model."
        echo "Raw response was:"
        echo "$response"
        return 1
    fi

    echo ""
    echo "Suggested commit message:"
    echo "-------------------------"
    echo "$message"
    echo "-------------------------"
    echo ""
    echo -n "Commit with this message? (y/n): "
    read confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        git commit -m "$message"
    else
        echo "$message" | pbcopy
        echo "Not committed. Message copied to clipboard instead."
    fi
}

why() {
    local cmd="$*"
    if [ -z "$cmd" ]; then
        echo "Usage: why <command to run and explain if it fails>"
        return 1
    fi

    local output
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    echo "$output"

    if [ $exit_code -eq 0 ]; then
        return 0
    fi

    echo ""
    echo "Command failed with exit code $exit_code. Asking DGX for an explanation..."
    echo ""

    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': 'You explain why a command failed in plain English, based on the command and its error output. Be concise, a few sentences max, and suggest a likely fix if one is obvious.'},
        {'role': 'user', 'content': 'Command: ' + sys.argv[1] + chr(10) + chr(10) + 'Error output:' + chr(10) + sys.argv[2]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$cmd" "$output")

    local response
    response=$(curl -s -m 30 "$DGX_ENDPOINT/chat/completions" \
        -H "Authorization: Bearer $DGX_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if [ -z "$response" ]; then
        echo "Error: no response from DGX endpoint."
        return $exit_code
    fi

    local explanation
    explanation=$(printf '%s' "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'].strip())
except Exception:
    print('PARSE_ERROR', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$explanation" ]; then
        echo "Error: could not parse a valid response from the model."
        return $exit_code
    fi

    echo "Explanation:"
    echo "$explanation"

    return $exit_code
}

whatdoes() {
    local query="$*"
    if [ -z "$query" ]; then
        echo "Usage: whatdoes <command> [flag], e.g. whatdoes tar -xvf"
        return 1
    fi

    local payload
    payload=$(python3 -c "
import json, sys
body = {
    'model': '$DGX_MODEL',
    'messages': [
        {'role': 'system', 'content': 'You explain what a specific command or command flag does. Be concise, a few sentences max, focused on practical usage.'},
        {'role': 'user', 'content': sys.argv[1]}
    ],
    'chat_template_kwargs': {'enable_thinking': False}
}
print(json.dumps(body))
" "$query")

    local response
    response=$(curl -s -m 30 "$DGX_ENDPOINT/chat/completions" \
        -H "Authorization: Bearer $DGX_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if [ -z "$response" ]; then
        echo "Error: no response from DGX endpoint."
        return 1
    fi

    local answer
    answer=$(printf '%s' "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'].strip())
except Exception:
    print('PARSE_ERROR', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$answer" ]; then
        echo "Error: could not parse a valid response from the model."
        return 1
    fi

    echo "$answer"
}
export PATH="$HOME/.local/bin:$PATH"
