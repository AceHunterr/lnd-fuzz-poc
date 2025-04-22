#!/usr/bin/env bash
set -e

# Enter project root
cd "$(dirname "$0")"/..

# Update LND submodule
git submodule update --init --recursive
cd lnd
git fetch origin
git checkout master
git pull origin master
cd ..

# Update fuzz-corpus submodule
cd lnd-fuzz
git fetch origin
git checkout main
git pull origin main
cd ..

# Stage and commit submodule pointer changes
git add lnd lnd-fuzz
git commit -m "chore: update LND and fuzz-corpus submodules"
git push origin master:main
