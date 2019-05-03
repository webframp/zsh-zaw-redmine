#!/usr/bin/env zsh
## Supporting functions
function redmine_url() {
    local url
    if [[ -v REDMINE_URL ]]; then
        url=$REDMINE_URL
    elif [ -f .redmine-url ]; then
        url=$(cat .redmine-url)
    elif [ -f ~/.redmine-url ]; then
        url=$(cat ~/.redmine-url)
    else
        echo "Redmine url is unset"
        return 1
    fi
    echo $url
}

typeset -gx issue_cache_file="$HOME/.cache/redmine/issues.json"
typeset -gx redmine_url=$(redmine_url)

function redmine_issue() {
    if [ -z "$1" ]; then
        echo "Opening new issue"
        open "${redmine_url}/issues/new"
    else
        local ticket
        ticket=$(echo $@ | cut -d' ' -f1)
        open "${redmine_url}/issues/$ticket"
    fi
}

function redmine_curl() {
    if [[ ! -v REDMINE_API_KEY ]]; then
        echo "Redmine api key is unset"
        return 1
    fi
    curl -s -H "X-Redmine-API-Key: $REDMINE_API_KEY" "$@"
}

function fetch_issues() {
    if [[ ! -d "$issue_cache_file" ]]; then
        mkdir -p "$issue_cache_file:h" # like dirname
    fi
    redmine_curl "${redmine_url}/issues.json?assigned_to_id=me" >! "$issue_cache_file"
}

## ZAW setup
function zaw-src-redmine() {
    typeset -a issues
    fetch_issues
    jq -r '.issues[]| "\(.id) \(.subject) [\(.status.name)] - \(.tracker.name)"' "$issue_cache_file" | while read -r line; do
        issues+=$line
    done

    candidates=($issues)
    actions=(zaw-callback-open-redmine-issue zaw-callback-create-redmine-issue)
    act_descriptions=('open issue' 'create issue' 'refresh issues')
    #TODO implement close/start (in progress) actions
}

function zaw-callback-open-redmine-issue() {
    local result
    result=$(echo "$1" | cut -d' ' -f1)
    BUFFER="redmine_issue $result"
    zle accept-line
}

function zaw-callback-create-redmine-issue() {
    BUFFER="redmine_issue"
    zle accept-line
}

if [[ -n $(declare -f -F zaw-register-src) ]]; then
    zaw-register-src -n redmine zaw-src-redmine
else
    echo "zaw-redmine plugin not loaded since zaw is not loaded."
    echo "Please load zaw (https://github.com/zsh-users/zaw) first."
fi
