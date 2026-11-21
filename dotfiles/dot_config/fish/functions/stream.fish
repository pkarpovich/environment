function stream --description "play a live stream through streamcast: stream [platform] <channel>"
    switch (count $argv)
        case 1
            set -f platform twitch
            set -f channel $argv[1]
        case 2
            set -f platform $argv[1]
            set -f channel $argv[2]
        case '*'
            echo "usage: stream [platform] <channel>" >&2
            return 1
    end
    if test -z "$STREAMCAST_URL"
        echo "stream: STREAMCAST_URL is not set, set it in ~/.config/fish/local.fish" >&2
        return 1
    end
    for name in $platform $channel
        if not string match -qr -- '^[A-Za-z0-9_-]+$' $name
            echo "stream: '$name' may use letters, digits, _ and - only" >&2
            return 1
        end
    end
    set -l header (oauth-token token --header streamcast); or return
    printf '%s\n' $header | curl -fsSN -H @- "$STREAMCAST_URL/stream/$platform/$channel" | mpv --force-media-title="$platform/$channel" -
    set -l statuses $pipestatus
    if test $statuses[2] -ne 0
        return $statuses[2]
    end
    return $statuses[3]
end
