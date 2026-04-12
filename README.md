docker compose -f setup.yml up -d --build

方法 B：使用臨時容器（不需啟動主服務時使用）
如果你只想單純把東西丟進 Volume，不想啟動原本的服務：
docker run --rm -v test_master_share_volume:/target -v $(pwd):/backup ubuntu cp -r /backup/. /target

docker compose up -d