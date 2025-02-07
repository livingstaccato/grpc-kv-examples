#!/bin/bash

# there is a much better way to do this.
alias p3="python3"
unalias p3
alias p3="python3"

# we are gonna source the venv stuff. so let us get rid of this.
alias python3=""
unalias python3

alias python=""
unalias python

alias show_relative_imports="pyrgi -g '**/*.py' -e '^from \.' | cut -d : -f -1 | sed -E 's|/[[:alnum:]_]+\.py$||g' | sort -h | uniq -c | sort -n"

source $(pwd)/.venv/bin/activate

export PATH="$(pwd)/.venv/bin:$(pwd):$(pwd)/scripts:$(pwd)/tools:${PATH}"

export PYTHONPATH=$(pwd)/python:${PYTHONPATH}
