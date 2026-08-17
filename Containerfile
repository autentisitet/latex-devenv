FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

WORKDIR /workspace

COPY installer.sh /tmp/installer.sh
RUN chmod +x /tmp/installer.sh \
    && /tmp/installer.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/installer.sh

COPY . /workspace
RUN chmod +x /workspace/ltx-build.sh

CMD ["bash"]
