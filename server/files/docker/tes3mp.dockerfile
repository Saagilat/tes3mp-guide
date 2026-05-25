FROM debian:11-slim

RUN apt-get update && apt-get install -y \
    libluajit-5.1-2 \
    libcurl4 \
    libssl1.1 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

COPY data/ /tes3mp/
RUN rm -f \
    /tes3mp/tes3mp-server-default.cfg \
    /tes3mp/server/scripts/config.lua \
    /tes3mp/server/data/requiredDataFiles.json \
    /tes3mp/server/data/banlist.json \
    && rm -rf /tes3mp/server/data/player /tes3mp/server/data/cell
WORKDIR /tes3mp
EXPOSE 25565/tcp
EXPOSE 25565/udp
CMD ["./tes3mp-server"]