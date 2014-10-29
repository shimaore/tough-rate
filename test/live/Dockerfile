FROM shimaore/freeswitch
COPY conf/ /usr/local/freeswitch/conf
CMD ["/usr/local/freeswitch/bin/freeswitch","-nf","-nosql","-nonat","-nonatmap","-nocal","-nort","-c"]
EXPOSE 5062/udp 5062/tcp 8022/tcp
