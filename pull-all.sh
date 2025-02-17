#!/bin/bash

#+43037769bafbf52325745e4259f1092bbe720677 Frontend (...)
readarray repos < <(git submodule | sed -rne 's/^[ +][0-9a-f]+ ([^ ]+)( \(.*\))?$/\1/p'; echo .)
for repo in ${repos[@]}; do git -C "$repo" pull |& sed -e "s/^/$repo: /"; done
for repo in ${repos[@]}; do git -C "$repo" pull --tags |& sed -e "s/^/$repo: /"; done
