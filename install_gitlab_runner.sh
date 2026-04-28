#!/bin/bash

# 定義變數方便日後修改
RUNNER_VERSION="16.0.0"
GITLAB_URL="https://gitlabvm.asusautomation.com:5050/"
GITLAB_TAG="stan***-ot"
REGISTRATION_TOKEN="LNDaekUf****QzLUBdL"
CERT_FILE="gitlabvm.asusautomation.com.crt"
SERVICE_HOSTNAME="gitlabvm.asusautomation.com"
SERVICE_HOSTNAME_PXE="gitlabvm.qt.org"

# 色彩定義
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

prepare_args() {
  echo -e -n "\e[0;33mPlease enter required arguments:"
  echo -e -n '\e[0;0m'
  echo ""
  options=("Automation" "PXE")

  select opt in "${options[@]}"; do
    case $opt in
      "Automation")
        SERVICE_HOSTNAME=$SERVICE_HOSTNAME
        GITLAB_URL="https://${SERVICE_HOSTNAME}:5050/"
        break
        ;;
      "PXE")
        SERVICE_HOSTNAME=$SERVICE_HOSTNAME_PXE
        GITLAB_URL="https://${SERVICE_HOSTNAME}:5050/"
        break
        ;;
      *) echo "Invalid option $REPLY";;
    esac
  done
}
prepare_args
echo "Selected $opt"
echo "prepare env ...."
echo "env $GITLAB_URL"

extract_domain() {
    local input=$1
    # 移除傳入網址的通訊協定部分
    local domain=$(echo "$input" | sed -e 's|^[^/]*//||' -e 's|/.*$||' | cut -d':' -f1)
    echo "$domain"
}

check_gitlab_reachability() {
    local TARGET_URL=$1
    SERVICE_HOSTNAME=$(extract_domain "$TARGET_URL")
    echo -e "${YELLOW}正在檢查服務連線 ($SERVICE_HOSTNAME)...${NC}"
    # -c 3: 傳送 3 個封包
    # -W 2: 等待回應的逾時時間為 2 秒 (避免沒回應時等太久)
    # > /dev/null 2>&1: 將標準輸出與錯誤訊息隱藏，不干擾畫面
    if ping -c 3 -W 2 "$SERVICE_HOSTNAME" > /dev/null 2>&1; then
        echo -e "${GREEN}成功：伺服器 $SERVICE_HOSTNAME 在線中。${NC}"
    else
        echo -e "${RED}錯誤：無法連線至 $SERVICE_HOSTNAME，請檢查網路或服務狀態。${NC}"
        # 視需求決定是否退出腳本
        exit 1
    fi
}

check_gitlab_reachability $GITLAB_URL

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