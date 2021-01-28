#!/bin/bash
##
# Copy default config files to mounted volumes

# First work around systemd not giving us the environment
for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

env

# Always export the docs dir to the volume mounted from the host.
cp -pRuv /usr/share/doc/httpd.default/* /usr/share/doc/httpd/

# Copy other config files if they are missing or an update is forced.
for CUR_DIR in $(tr ',' '\n' <<< "${VOLUMES}") ; do \
    if [ -f ${CUR_DIR}/.forceinit ] || [ ! "$(ls -A ${CUR_DIR}/)" ]; then
        if [ -d /usr/share/doc/http.default/config${CUR_DIR} ]; then
            cp -pRv /usr/share/doc/http.default/config${CUR_DIR}/* ${CUR_DIR}/
        fi
    fi
done

touch /etc/init_done

