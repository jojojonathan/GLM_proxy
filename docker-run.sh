#!/usr/bin/env bash
# glmproxy 一键启动：构建镜像（如缺失）并以云端上游模式运行。
# token 数据来自 Windows 宿主机的 AutoClaw 数据目录（只读挂载）。
set -euo pipefail

# ===== 可调参数 =====
IMAGE_NAME="glmproxy-local"
CONTAINER_NAME="glmproxy"
PORT=18791                      # 对外监听端口（容器内外一致）
PROXY_KEY="glmp-wsl-2026"       # 客户端 Bearer key（默认 mewmew，0.0.0.0 下建议改掉）
UPSTREAM_HOST="autoglm-acceleration-api.zhipuai.cn"   # AutoClaw 1.18.x 云端上游
LOG_LEVEL="info"
# Windows 侧 AutoClaw 数据目录（含 request-headers.json，token 自动轮换靠它热更新）
AUTCLAW_DATA_DIR="/mnt/c/Users/64264/.openclaw-autoclaw"
# 容器内挂载点：node 镜像默认 root 用户，os.homedir() 即 /root
CONTAINER_DATA_DIR="/root/.openclaw-autoclaw"

if [ ! -f "$AUTCLAW_DATA_DIR/request-headers.json" ]; then
  echo "错误：找不到 $AUTCLAW_DATA_DIR/request-headers.json" >&2
  echo "请确认 Windows 侧 AutoClaw 已安装并登录过，路径可通过 AUTCLAW_DATA_DIR 变量修改。" >&2
  exit 1
fi

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "镜像 $IMAGE_NAME 不存在，开始构建..."
  docker build -t "$IMAGE_NAME" "$(cd "$(dirname "$0")" && pwd)"
fi

# 幂等：同名容器（无论运行/停止）先删再建
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${PORT}:${PORT}" \
  -v "${AUTCLAW_DATA_DIR}:${CONTAINER_DATA_DIR}:ro" \
  -e "HOST=0.0.0.0" \
  -e "PORT=${PORT}" \
  -e "PROXY_KEY=${PROXY_KEY}" \
  -e "AUTOCLAW_PROXY_UPSTREAM_HOST=${UPSTREAM_HOST}" \
  -e "LOG_LEVEL=${LOG_LEVEL}" \
  -e "JSONL_LOG=true" \
  "$IMAGE_NAME"

echo "容器 $CONTAINER_NAME 已启动，等待服务就绪..."
for i in $(seq 1 15); do
  if curl -sf -o /dev/null "http://localhost:${PORT}/v1/models" -H "Authorization: Bearer ${PROXY_KEY}"; then
    echo "就绪：http://localhost:${PORT}/v1  (PROXY_KEY=${PROXY_KEY})"
    exit 0
  fi
  sleep 1
done

echo "警告：服务 ${PORT} 端口 15 秒内未就绪，查看日志：docker logs $CONTAINER_NAME" >&2
exit 1
