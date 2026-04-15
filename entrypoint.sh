#!/bin/bash

# 啟動 sshd 並保持在前景 (PID 1)
exec /usr/sbin/sshd -D

