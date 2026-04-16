#!/bin/bash

# 定義變數方便日後修改
RUNNER_VERSION="16.0.0"
GITLAB_URL="https://gitlabvm.asusautomation.com"
GITLAB_TAG="stanley-bot"
REGISTRATION_TOKEN="p7PixG****23Dz"
CERT_FILE="gitlabvm.asusautomation.com.crt"

echo "--- 開始安裝 GitLab Runner $RUNNER_VERSION ---"

# 1. 新增 Repo 並安裝指定版本
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner=$RUNNER_VERSION -y

if ! command -v gitlab-runner &> /dev/null
then
    echo "錯誤：gitlab-runner 安裝失敗，請檢查網路或軟體源設定。"
    exit 1
fi

# 2. 設定免密碼 sudo (建議用 sudoers.d)
echo "gitlab-runner ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/gitlab-runner

# 3. 抓取 SSL 憑證並更新
openssl s_client -showcerts -servername gitlabvm.asusautomation.com -connect gitlabvm.asusautomation.com:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > $CERT_FILE
sudo cp $CERT_FILE /usr/local/share/ca-certificates/
sudo update-ca-certificates

# 4. 設定 Docker Insecure Registries
sudo mkdir -p /etc/docker
echo -e "{\n\t\"insecure-registries\" : [\"gitlabvm.asusautomation.com:5005\"]\n}" | sudo tee /etc/docker/daemon.json > /dev/null
sudo systemctl daemon-reload
sudo systemctl restart docker

# 5. Git 全域設定
sudo git config --system http.sslVerify false

# 6. 非互動式註冊 Runner (優化重點)
sudo gitlab-runner register \
  --non-interactive \
  --url "$GITLAB_URL" \
  --registration-token "$REGISTRATION_TOKEN" \
  --executor "shell" \
  --description "Auto-configured Runner" \
  --tag-list "$GITLAB_TAG" \
  --run-untagged="true" \
  --locked="false"

# 7. 重啟服務
sudo gitlab-runner restart
xhost + || echo "xhost setup skipped (no display found)"

echo "--- 安裝與註冊完成 ---"