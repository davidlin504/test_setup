#!/bin/bash

# --- 設定變數 (可根據需求修改) ---
WIN_USER="123"
WIN_PASSWORD="123"
CIFS_IP="192.168.87.191"
NFS_IP="192.168.87.121"

# 遠端路徑與在地掛載點
CIFS_REMOTE="//${CIFS_IP}/Users/123/Desktop/reports/fw"
CIFS_LOCAL="/mnt/win_share"
NFS_REMOTE="${NFS_IP}:/var/lib/tftpboot"
NFS_LOCAL="/mnt/linux_share"
MOUNT_POINTS=("$NFS_LOCAL" "$CIFS_LOCAL")

# 色彩定義
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
NC='\e[0m' # No Color

echo -e "${GREEN}======== [Mount Test Data Wizard] ========${NC}\n"

# 權限檢查 (掛載需要 sudo)
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}錯誤: 請使用 sudo 執行此腳本${NC}"
   exit 1
fi

# 1. 準備掛載目錄 (檢查是否存在)
check_and_create_dir() {
    if [ ! -d "$1" ]; then
        echo -e "${YELLOW}目錄 $1 不存在，正在建立...${NC}"
        mkdir -p "$1"
    fi
}

# 2. 檢查是否已掛載
is_mounted() {
    mountpoint -q "$1"
}

# 3. 卸載邏輯
handle_umount() {
    local target=$1
    if is_mounted "$target"; then
        read -p "偵測到 $target 已掛載，是否先卸載 (umount)? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            umount -l "$target" && echo -e "${GREEN}已成功卸載 $target${NC}"
        else
            echo -e "${YELLOW}跳過卸載，將嘗試直接操作...${NC}"
        fi
    fi
}

umount_all() {
    echo -e "${GREEN}準備卸載所有掛載點！${NC}"

    for point in "${MOUNT_POINTS[@]}"; do
        handle_umount "$point"
    done
    echo -e "${GREEN}卸載完成！${NC}"
    exit 0
}

# 4. 互動式主程式
main() {
    echo -e "${YELLOW}請選擇掛載或是卸載:${NC}"
    echo "1) 掛載"
    echo "2) 卸載"
    read -e -i "" -p "輸入選項 [1 或 2]: " choice
    if [ "$choice" == "2" ]; then
        umount_all
    elif [ "$choice" == "" ]; then
        echo -e "${RED}無效選項，退出。${NC}"
        exit 1
    fi

    # 選擇模式
    echo -e "${YELLOW}請選擇掛載方式:${NC}"
    echo "1) NFS (Linux Share)"
    echo "2) CIFS (Windows Share)"
    read -e -i "1" -p "輸入選項 [1 或 2]: " choice

    if [ "$choice" == "1" ]; then
        # --- NFS 流程 ---
        check_and_create_dir "$NFS_LOCAL"
        handle_umount "$NFS_LOCAL"

        echo -e "${GREEN}執行 NFS 掛載: ${NFS_REMOTE} -> ${NFS_LOCAL}${NC}"
        mount -t nfs "$NFS_REMOTE" "$NFS_LOCAL"

    elif [ "$choice" == "2" ]; then
        # --- CIFS 流程 ---
        check_and_create_dir "$CIFS_LOCAL"
        handle_umount "$CIFS_LOCAL"

        echo -e "${GREEN}執行 CIFS 掛載: ${CIFS_REMOTE} -> ${CIFS_LOCAL}${NC}"
        mount -t cifs "$CIFS_REMOTE" "$CIFS_LOCAL" -o username="${WIN_USER}",password="${WIN_PASSWORD}",iocharset=utf8

    else
        echo -e "${RED}無效選項，退出。${NC}"
        exit 1
    fi

    # 最終檢查
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}操作成功！目前掛載狀態：${NC}"
        df -h | grep -E "(${CIFS_LOCAL}|${NFS_LOCAL})"
    else
        echo -e "\n${RED}操作失敗，請檢查網路或權限。${NC}"
    fi
}

main