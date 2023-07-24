FROM ubuntu:22.04
RUN groupadd --system --gid 101 nginx \
    && useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx \
    && mkdir -p /var/log/nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx /var/cache/nginx \
    && apt-get update \
    && apt-get install -y net-tools watch telnet curl ca-certificates openssl host \
    && rm -rf /var/lib/apt/lists/*
COPY bin/nginx /usr/sbin/nginx
CMD ["nginx","-g","daemon off;"]