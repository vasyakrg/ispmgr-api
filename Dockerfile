FROM vasyakrg/curl

COPY assets/ /

RUN chmod +x /usr/local/sbin/*.sh
WORKDIR /usr/local/sbin/
