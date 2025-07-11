#!/usr/bin/env bash

echo -n 'checking ... '

fail=false

if ! shellcheck --shell=bash --exclude=1117,2013,2018,2019,2120,2034,2086,2119,2155,2181 ./shared/*.sh; then
    fail=true
    echo
fi

[[ $fail = true ]] && echo 'failed!' || echo 'passed!'
