FROM ubuntu:22.04

# 設定環境變數，避免安裝過程出現互動提示
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 \
    ca-certificates \
    curl

# 2. 直接下載金鑰並存入 keyring
RUN mkdir -p /etc/apt/keyrings && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF23C5A6CF475977595C89F51BA6932366A755776" | \
    gpg --dearmor -o /etc/apt/keyrings/deadsnakes.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/deadsnakes.gpg] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes.list

# # 2. 手動導入 deadsnakes 的金鑰並加入軟體源
# RUN mkdir -p /etc/apt/keyrings && \
#     gpg --no-default-keyring --keyring /etc/apt/keyrings/deadsnakes.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 && \
#     echo "deb [signed-by=/etc/apt/keyrings/deadsnakes.gpg] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes.list

# 1. 基礎系統套件與 Python 3.12, Git
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
        python3-pip \
        git \
        openssh-server \
        rpcbind \
        iproute2 \
        curl \
        vim \
    && rm -rf /var/lib/apt/lists/*

# 1. 安裝 NVM 與 Node.js
# 設定 NVM 安裝路徑
ENV NVM_DIR=/root/.nvm
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# 2. 在同一個 RUN 指令中完成安裝，避免環境變數丟失
# 這裡安裝 Node 20 並啟動 Corepack (Yarn)
RUN . $NVM_DIR/nvm.sh && \
    nvm install 20 && \
    nvm use 20 && \
    nvm alias default 20 && \
    corepack enable && \
    corepack prepare yarn@stable --activate

# 3. 關鍵修正：手動設定 PATH (取代原本報錯的 ENV 指令)
# NVM 的路徑結構通常很固定：$NVM_DIR/versions/node/v[版本號]/bin
# 我們直接將這個路徑加入系統 PATH
ENV PATH=$NVM_DIR/versions/node/v20.11.1/bin:$PATH

# 設定 SSH 必要配置
RUN mkdir /var/run/sshd && \
    echo 'root:password123' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 如果你想要更動態一點，可以用軟連結方式 (在 RUN 裡面做)
RUN ln -s $(. $NVM_DIR/nvm.sh && nvm which default) /usr/local/bin/node && \
    ln -s $(. $NVM_DIR/nvm.sh && which yarn) /usr/local/bin/yarn

RUN ln -s /usr/bin/python3.12 /usr/bin/python

# 修正 SSH 登入問題，確保環境變數正確載入
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

# 開放連接埠
EXPOSE 22 111

# 啟動腳本：同時開啟 rpcbind 與 sshd
# 使用 -D 讓 sshd 在前景執行，防止容器退出
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]