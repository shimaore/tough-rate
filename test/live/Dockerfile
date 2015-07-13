FROM shimaore/freeswitch:2.1.0
COPY conf/ /opt/freeswitch/conf
CMD ["/opt/freeswitch/bin/freeswitch","-nf","-nosql","-nonat","-nonatmap","-nocal","-nort","-c"]
EXPOSE 5062/udp 5062/tcp 8022/tcp
