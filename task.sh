#!/bin/bash

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SCRIPTS_DIR=$PROJECT_DIR/public

$SCRIPTS_DIR/task.sh $@
