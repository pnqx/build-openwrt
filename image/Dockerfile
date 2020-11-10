ARG BASE_IMAGE=pnq/alpine
FROM $BASE_IMAGE
RUN apk add tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apk del tzdata
RUN apk add asciidoc bash bc binutils bzip2 cdrkit coreutils diffutils findutils flex g++ gawk gcc gettext git grep intltool libxslt linux-headers make ncurses-dev patch perl python2-dev python3-dev rsync tar unzip util-linux wget zlib-dev
RUN apk add shadow
RUN apk add glib glib-dev libstdc++ build-base fakeroot
WORKDIR /openwrt
ARG WHO_UID=""
RUN if [ "$WHO_UID" = "" ]; then useradd who; else useradd --uid $WHO_UID who; fi
COPY docker-entrypoint.sh /
RUN chmod =xxx /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh" ]
CMD ["-i"]


