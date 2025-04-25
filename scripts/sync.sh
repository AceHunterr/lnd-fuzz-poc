#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"/..

git submodule update --init --recursive
cd lnd
git fetch origin
git checkout master
git pull origin master
cd ..

cd lnd-fuzz
git fetch origin
git checkout main
git pull origin main
cd ..

# git add lnd lnd-fuzz
# git commit -m "chore: update LND and fuzz-corpus submodules"
# git push origin master:main
