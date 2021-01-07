#!/bin/bash

set -x
# Work around systemd not gving us the environment
for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

env

##
# Chown important directories

# Chown a list of directories we always do GID 0
if [ -n "${CHOWN}" ]; then
	for CUR_DIR in $(tr ',' '\n' <<< "${CHOWN_DIRS}") ; do
        chown -vR $CHOWN_USER:0 $CUR_DIR
        chmod -v 770 $CUR_DIR
    done
fi  

