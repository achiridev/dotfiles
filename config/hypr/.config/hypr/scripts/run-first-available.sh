#!/usr/bin/env bash

for cmd in "$@"; do
    [[ -z "$cmd" ]] && continue

    exe=${cmd%% *}

    command -v "$exe" >/dev/null 2>&1 || continue

    eval "$cmd" &
    exit 0
done

echo "run-first: no available command found" >&2
exit 127
