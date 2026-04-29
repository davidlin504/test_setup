#!/bin/bash

# 色彩定義
GREEN='\e[0;32m'
BLUE='\e[0;34m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

TARGET_HOST=$1

if [[ -z "$TARGET_HOST" ]]; then
  echo -e "${RED}Error: TARGET_HOST cannot be empty!${NC}"
  exit 1
fi

extract_domain() {
    local input=$1
    # 移除傳入網址的通訊協定部分
    local domain=$(echo "$input" | sed -e 's|^[^/]*//||' -e 's|/.*$||' | cut -d':' -f1)
    echo "$domain"
}

check_gitlab_reachability() {
    local TARGET_URL=$1
    SERVICE_HOSTNAME=$(extract_domain "$TARGET_URL")
    echo -e "${BLUE}[Info]${NC} 正在檢查服務連線 ($SERVICE_HOSTNAME)..."
    # -c 3: 傳送 3 個封包
    # -W 2: 等待回應的逾時時間為 2 秒 (避免沒回應時等太久)
    # > /dev/null 2>&1: 將標準輸出與錯誤訊息隱藏，不干擾畫面
    if ping -c 3 -W 2 "$SERVICE_HOSTNAME" > /dev/null 2>&1; then
        echo -e "${GREEN}[Success]${NC} 伺服器 $SERVICE_HOSTNAME 在線中。"
    else
        echo -e "${RED}[Error]錯誤${NC} 無法連線至 $SERVICE_HOSTNAME，請檢查網路或DNS。"
        # 視需求決定是否退出腳本
        exit 1
    fi
}

check_gitlab_reachability $TARGET_HOST