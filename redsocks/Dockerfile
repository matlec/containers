#############################################
# Stage "builder"
#############################################
FROM frolvlad/alpine-gcc AS builder

ADD build-context.tar.gz .
RUN apk add --no-cache make iptables-dev libevent-dev
RUN make

#############################################
# Stage "final"
#############################################
FROM alpine:latest AS final

COPY --from=builder /redsocks /bin/redsocks
COPY --from=builder /rootfs /
RUN set -ex ;\
    apk add --no-cache iptables libevent bash ;\
	chmod +x /bin/redsocks ;\
    chmod +x /bin/redsocks.sh ;

ENTRYPOINT ["/bin/redsocks.sh"]
CMD ["start"]