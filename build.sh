#!/bin/bash
set -e
. .env

AS_LATEST=false
PUSH=false
NO_BUILD=false

options=$(getopt -o lp --long latest,push,nobuild -- "$@")
eval set -- "$options"
while true; do
    case $1 in
    -l | --latest)
        echo "as latest"
        AS_LATEST=true
        shift
        ;;
    -p | --push)
        echo "do push"
        PUSH=true
        shift
        ;;
    --nobuild)
        echo "no build"
        NO_BUILD=true
        shift
        ;;
    --)
        shift
        break
        ;;
    *) break ;;
    esac
done

function build() {
    mkdir -p bin
    if [ ! -e ngx_healthcheck_module ]; then
        git clone git@github.com:zhouchangxun/ngx_healthcheck_module.git
    else
        cd ngx_healthcheck_module
        git pull
        cd ..
    fi
    if [ ! -e nginx ]; then
        git clone git@github.com:nginx/nginx.git
    else
        cd nginx
        git reset --hard
        git co master && git pull
        cd ..
    fi

    cd nginx
    # checkout specific version
    git checkout release-$NGINX_VERSION
    # apply patch for ngx_healthcheck_module
    git apply ../ngx_healthcheck_module/nginx_healthcheck_for_nginx_1.19+.patch

    # clean and build
    if [ -e Makefile ]; then
        make clean
    fi
    ./auto/configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx --group=nginx \
        --with-compat --with-file-aio --with-threads \
        --with-http_addition_module --with-http_auth_request_module \
        --with-http_dav_module --with-http_flv_module --with-http_gunzip_module \
        --with-http_gzip_static_module --with-http_mp4_module \
        --with-http_random_index_module --with-http_realip_module \
        --with-http_secure_link_module --with-http_slice_module \
        --with-http_ssl_module --with-http_stub_status_module \
        --with-http_sub_module --with-http_v2_module --with-http_v3_module \
        --with-mail --with-mail_ssl_module \
        --with-stream --with-stream_realip_module --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
        --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
        --add-module=../ngx_healthcheck_module/
    make -j 16
    cp objs/nginx ../bin/
    cd ..
}

if [ "$NO_BUILD" = false ]; then
    build
fi

# build docker image
docker image build -t $IMAGE_NAME:$NGINX_VERSION .
if [ "$AS_LATEST" = true ]; then
    docker image tag $IMAGE_NAME:$NGINX_VERSION $IMAGE_NAME:latest
fi

if [ "$PUSH" = true ]; then
    docker image push $IMAGE_NAME:$NGINX_VERSION
    if [ "$AS_LATEST" = true ]; then
        docker image push $IMAGE_NAME:latest
    fi
fi
