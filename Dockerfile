FROM gitlabvm.asusautomation.com:5005/ami-images/spx-taas:ASUS_v1.25_20250915

# 設定環境變數，避免安裝過程出現互動提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新並安裝必要工具：ssh, rpcbind, 以及常用的網管工具
RUN apt-get update && apt-get install -y \
    git \
    openssh-server \
    rpcbind \
    iproute2 \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 設定 SSH 必要配置
RUN mkdir /var/run/sshd && \
    echo 'root:password123' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

# 修正 SSH 登入問題，確保環境變數正確載入
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

# 開放連接埠
EXPOSE 2222


# 先確保目錄存在
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# 將本地的 id_pub.rsa 複製進去，並附加到 authorized_keys
COPY id_pub.rsa /tmp/id_pub.rsa
RUN cat /tmp/id_pub.rsa >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    rm /tmp/id_pub.rsa

# 啟動腳本：同時開啟 rpcbind 與 sshd
# 使用 -D 讓 sshd 在前景執行，防止容器退出

COPY ./entrypoint.sh entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
