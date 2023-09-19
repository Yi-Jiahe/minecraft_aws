# version 1.3.0
# docker pull yijiahe/minecraft-ecsfargate-watchdog

FROM amazon/aws-cli

RUN yum install -y net-tools jq nmap-ncat && \
    yum clean all

COPY ./watchdog.sh .

ENTRYPOINT ["./watchdog.sh"]
