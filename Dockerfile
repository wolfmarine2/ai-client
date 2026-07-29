FROM image.prod.dhzq.cn/library/ubuntu:26.04


#ssh key
COPY ssh/id_ed25519 /root/.ssh/id_ed25519
COPY ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub

COPY config.toml /opt/config.toml

RUN  apt-get update -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates gnupg curl wget sudo git locales jq openssh-client tzdata \
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && locale-gen en_US.UTF-8 \
  && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && dpkg-reconfigure -f noninteractive tzdata \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && chmod 600 /root/.ssh/id_ed25519 \
  && ssh-keyscan -p 9022 -H forgejo.prod.dhzq.cn >> /root/.ssh/known_hosts

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

RUN curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    mv kubectl /user/local/bin/kubectl && \
    chmod +x /user/local/bin/kubectl && \
    curl -sLO "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" && \
    tar -zxvf "helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" && \
    mv "linux-${TARGETARCH}/helm" /user/local/bin/helm && \
    chmod +x /user/local/bin/helm
    curl -sLO "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-${TARGETARCH}.gz" && \
    gunzip "argo-linux-${TARGETARCH}.gz" && \
    mv "argo-linux-${TARGETARCH}" /usr/local/bin/argo && \
    chmod +x /user/local/bin/argo

RUN cd /opt && \
    corepack enable && \
    corepack prepare yarn@4.11.0 --activate && \
    #config rust
    mkdir -p /root/.cargo && \
    mv config.toml /root/.cargo/config.toml && \ 
    #config python
    pip config set global.trusted-host mirrors.prod.dzhq.cn && \
    pip config set global.index http://mirrors.prod.dhzq.cn/repository/pypi/pypi && \
    pip config set global.index-url http://mirrors.prod.dhzq.cn/repository/pypi/simple && \
    #config npm
    npm config set registry http://mirrors.prod.dhzq.cn/repository/npm/ && \
    npm i -g pnpm && \
    pnpm config set registry http://mirrors.prod.dhzq.cn/repository/npm/ && \
    #opencode
    curl -fsSL https://opencode.ai/install | bash && \
    #qwen code
    curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash && \
    #codewhale
    curl -fsSL -o codewhale https://github.com/Hmbown/CodeWhale/releases/latest/download/codewhale-linux-x64 && \
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

#入口脚本
USER 0
WORKDIR /root
#ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]