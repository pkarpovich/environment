function proxy --description "toggle ClashX proxy env vars for the current session (on/off/status)"
    set -l url http://127.0.0.1:7890
    set -l vars HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

    switch "$argv[1]"
        case on ''
            for v in $vars
                set -gx $v $url
            end
            set -gx NO_PROXY localhost,127.0.0.1,::1
            set -gx no_proxy localhost,127.0.0.1,::1
            echo "🟢 proxy on -> $url"
        case off
            set -e $vars NO_PROXY no_proxy
            echo "⚪ proxy off"
        case status
            if set -q HTTP_PROXY
                echo "🟢 proxy on -> $HTTP_PROXY"
            else
                echo "⚪ proxy off"
            end
        case '*'
            echo "Usage: proxy [on|off|status]"
            return 1
    end
end

