FROM ubuntu:26.04


#ssh key
COPY config.toml /opt/config.toml
COPY ssh/id_ed25519 /root/.ssh/id_ed25519
COPY ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub

RUN  apt-get update -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates gnupg curl wget vim sudo git locales jq \
       openssh-client openssh-server tini tzdata \
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && locale-gen en_US.UTF-8 \
  && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && dpkg-reconfigure -f noninteractive tzdata \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && chmod 700 /root/.ssh \
  && chmod 600 /root/.ssh/id_ed25519

#操作系统基础设置
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TZ=Asia/Shanghai

#安装客户端
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential pkg-config libssl-dev openjdk-21-jdk maven nodejs npm python3 python3-pip python-is-python3 rustc \
  && apt-get install -y --no-install-recommends mariadb-client postgresql-client \
  && apt-get install -y --no-install-recommends proxychains4 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.32.9
ARG HELM_VERSION=v3.16.0
ARG ARGO_VERSION=v3.5.10

RUN curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    mv kubectl /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    curl -sLO "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" && \
    tar -zxvf "helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" && \
    mv "linux-${TARGETARCH}/helm" /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    curl -sLO "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-${TARGETARCH}.gz" && \
    gunzip "argo-linux-${TARGETARCH}.gz" && \
    mv "argo-linux-${TARGETARCH}" /usr/local/bin/argo && \
    chmod +x /usr/local/bin/argo

RUN cd /opt && \
    corepack enable && \
    corepack prepare yarn@4.11.0 --activate && \
    #config rust
    mkdir -p /root/.cargo && \
    mv config.toml /root/.cargo/config.toml && \
    #config python
    pip config set global.trusted-host mirrors.prod.dhzq.cn && \
    pip config set global.index http://mirrors.prod.dhzq.cn/repository/pypi/pypi && \
    pip config set global.index-url http://mirrors.prod.dhzq.cn/repository/pypi/simple && \
    #config npm
    npm i -g pnpm && \
    npm config set registry http://mirrors.prod.dhzq.cn/repository/npm/ && \
    pnpm config set registry http://mirrors.prod.dhzq.cn/repository/npm/ && \
    #opencode
    curl -fsSL https://opencode.ai/install | bash && \
    #qwen code
    curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash && \
    #codewhale
    ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo "arm64" || echo "x64") && \
    curl -fsSL -o codewhale https://github.com/Hmbown/CodeWhale/releases/latest/download/codewhale-linux-${ARCH} && \
    chmod +x codewhale && \
    xattr -d com.apple.quarantine codewhale 2>/dev/null || true && \
    mv codewhale /usr/local/bin/ && \
    #kimi code
    curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash

#通过二进制包安装软件
#COPY app /opt/
#RUN cd /opt \
#  && tar -xzf go1.25.4.linux-amd64.tar.gz \
#  && rm -f go1.25.4.linux-amd64.tar.gz 

#配置环境变量
#COPY profile /etc/profile
#COPY entrypoint.sh /usr/local/bin/
#RUN chmod +x /usr/local/bin/entrypoint.sh

#sshd 配置
COPY sshd_config.d/99-devpod.conf /etc/ssh/sshd_config.d/99-devpod.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN rm -f /etc/ssh/ssh_host_* \
  && mkdir -p /run/sshd /root/.ssh \
  && chmod 700 /root/.ssh \
  && chmod +x /usr/local/bin/entrypoint.sh \
  # 把构建期 PATH 固化，供非交互式 ssh 会话使用
  && echo "PATH=${PATH}:/root/.opencode/bin:/root/.qwen/bin:/root/.kimi/bin:/usr/local/bin" > /etc/environment

EXPOSE 22
USER root
WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["sshd"]
