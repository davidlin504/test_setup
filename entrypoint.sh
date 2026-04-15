#!/bin/bash
# # 啟動 rpcbind 並放到背景
# service rpcbind start

# 啟動 sshd 並保持在前景 (PID 1)
exec /usr/sbin/sshd -D