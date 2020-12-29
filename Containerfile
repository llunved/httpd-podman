ARG OS_RELEASE=33
ARG OS_IMAGE=fedora:$OS_RELEASE

FROM $OS_IMAGE as build

ARG OS_RELEASE
ARG OS_IMAGE
ARG HTTP_PROXY=""
ARG USER="httpd"
ARG VOLUMES_ARG="/etc/httpd /var/www /usr/share/httpd /var/log/httpd"

LABEL MAINTAINER riek@llunved.net

ENV LANG=C.UTF-8
ENV VOLUMES=$VOLUMES_ARG

USER root

RUN mkdir -p /httpd
WORKDIR /httpd

ADD ./rpmreqs-build.txt /httpd/

ENV http_proxy=$HTTP_PROXY
RUN dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$OS_RELEASE.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$OS_RELEASE.noarch.rpm \
    && dnf -y upgrade \
    && dnf -y install $(cat rpmreqs-build.txt) 

ADD ./rpmreqs-rt.txt ./rpmreqs-dev.txt /httpd/
# Create the minimal target environment
RUN mkdir /sysimg \
    && dnf install --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs -y coreutils-single glibc-minimal-langpack $(cat rpmreqs-rt.txt) \
    && if [ "${DEVBUILD}" == "True" ]; then dnf install --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs -y $(cat rpmreqs-dev.txt); fi \
    && rm -rf /sysimg/var/cache/*

#FIXME this needs to be more elegant
RUN ln -s /sysimg/usr/share/zoneinfo/America/New_York /sysimg/etc/localtime

# Set up systemd inside the container
RUN systemctl --root /sysimg mask systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount systemd-logind.service getty.target console-getty.service && systemctl --root /sysimg disable dnf-makecache.timer dnf-makecache.service
RUN /usr/bin/systemctl --root /sysimg enable httpd
 
# Move the httpd config to a deoc dir, so we can mount config from the host but export the defaults from the host
RUN if [ -d /sysimg/usr/share/doc/httpd ]; then \
       mv /sysimg/usr/share/doc/httpd /sysimg/usr/share/doc/httpd.default ; \
    else \
       mkdir -p /sysimg/usr/share/doc/httpd.default ; \
    fi ; \
    mkdir /sysimg/usr/share/doc/httpd.default/config

RUN for CURF in ${VOLUMES} ; do \
    if [ "$(ls -A /sysimg${CURF})" ]; then \
        mkdir -pv /sysimg/usr/share/doc/httpd.default/config${CURF} ; \
        mv -fv /sysimg${CURF}/* /sysimg/usr/share/doc/httpd.default/config${CURF}/ ;\
    fi ; \
    done


FROM scratch AS runtime

ARG VOLUMES_ARG="/etc/httpd /var/www /usr/share/httpd /var/log/httpd"

COPY --from=build /sysimg /

WORKDIR /var/lib/httpd

ENV USER=$USER
ENV CHOWN=true 
ENV CHOWN_DIRS="/var/www /etc/httpd" 
 
ENV VOLUMES=$VOLUMES_ARG
VOLUME $VOLUMES

ADD ./install.sh \ 
    ./upgrade.sh \
    ./uninstall.sh \
    ./init_container.sh /sbin
 
RUN chmod +x /sbin/install.sh \
             /sbin/upgrade.sh \
             /sbin/uninstall.sh \
             /sbin/init_container.sh
  
EXPOSE 80 443
CMD ["/usr/sbin/init"]
STOPSIGNAL SIGRTMIN+3

#FIXME - BROKE THESE WITH THE MOVE TO PODS
#LABEL RUN="podman run --rm -t -i --name ${NAME} --net=host -v /var/lib/${NAME}/www:/var/www:rw,z -v etc/${NAME}:/etc/${NAME}:rw,z -v /var/log/${NAME}:/var/log/${NAME}:rw,z ${IMAGE}"
#LABEL INSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/install.sh"
#LABEL UPGRADE="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/upgrade.sh"
#LABEL UNINSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e CONFDIR=/etc -e LOGDIR=/var/log -e DATADIR=/var/lib --entrypoint /bin/sh  \$IMAGE /sbin/uninstall.sh"

