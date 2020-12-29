#!/bin/bash

env

##
# Copy default config files to mounted volumes

# Make sure that we have required directories in the host

cp -pRv /usr/share/doc/httpd.default/* /usr/share/doc/httpd/

for CUR_DIR in ${VOLUMES} ; do
    if [ -f ${CUR_DIR}/.forceinit ] || [ ! "$(ls -A ${CUR_DIR}/)" ]; then
        if [ -d /usr/share/doc/httpd.default/config${CUR_DIR} ]; then
            cp -pRv /usr/share/doc/httpd.default/config${CUR_DIR}/* ${CUR_DIR}/
        fi
    fi 
done

