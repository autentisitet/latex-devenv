FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

WORKDIR /workspace

COPY installer.sh ltx-build.sh ./
RUN chmod +x installer.sh \
    && ./installer.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY template/ ./template/
RUN chmod +x ./ltx-build.sh

CMD ["bash"]