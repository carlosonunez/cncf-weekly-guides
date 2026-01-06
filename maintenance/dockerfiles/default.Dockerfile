FROM ubuntu:questing

RUN apt -y update
RUN apt -y install jq curl bash git

RUN arch=arm64; \
    uname -a | grep -q 'x86_64' && arch=amd64; \
    curl -Lo /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/v4.50.1/yq_linux_$arch"; \
    chmod +x /usr/local/bin/yq

COPY scripts /scripts
ENTRYPOINT [ "bash" ]
