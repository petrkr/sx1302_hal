ARG BUILDER_IMAGE=debian:12-slim
ARG RUNNER_IMAGE=debian:12-slim
FROM ${BUILDER_IMAGE} as builder

RUN apt update && apt -y upgrade && apt install -y build-essential linux-libc-dev jq

WORKDIR /usr/src/sx1302_hal

ADD . /usr/src/sx1302_hal/

RUN make clean && make
RUN sed -i 's/localhost/miner/' /usr/src/sx1302_hal/packet_forwarder/global_conf.*

FROM ${RUNNER_IMAGE} as runner

RUN apt-get update && \
    apt-get install -y gpiod && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/packet_forwarder

COPY --from=builder /usr/src/sx1302_hal/packet_forwarder/lora_pkt_fwd /opt/packet_forwarder/
COPY --from=builder /usr/src/sx1302_hal/tools/reset_lgw.sh* /opt/packet_forwarder/tools/
COPY --from=builder /usr/src/sx1302_hal/packet_forwarder/global_conf.* /opt/packet_forwarder/default_configs/

ADD entrypoint.sh /opt/packet_forwarder/

ENTRYPOINT ["/opt/packet_forwarder/entrypoint.sh"]
