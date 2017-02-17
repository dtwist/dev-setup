#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

function doIt() {
    rsync -avh --no-perms \
      --include ".aliases" \
      --include ".bash*" \
      --include ".curlrc" \
      --include ".exports" \
      --include ".functions" \
      --include ".hushlogin" \
      --include ".inputrc" \
      --include ".screenrc" \
      --include ".wgetrc" \
      . ~;
    source ~/.bash_profile;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
    doIt;
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        doIt;
    fi;
fi;
unset doIt;
