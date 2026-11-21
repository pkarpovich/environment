function oauth-token --description "sign in once with the OAuth device grant, print access tokens"
    set -l script_path ~/Projects/environment/scripts/oauth_token.py

    if not test -f $script_path
        echo "Error: oauth_token.py not found at $script_path" >&2
        return 1
    end

    python3 $script_path $argv
end
