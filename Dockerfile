FROM python:3.11-slim

# 设置 Python 环境变量
# PYTHONUNBUFFERED=1: 禁止输出缓冲，确保 MCP stdio 消息实时发送
# PYTHONDONTWRITEBYTECODE=1: 避免生成 .pyc 文件
# NCBI_API_KEY: NCBI API 密钥，可在 docker run 时通过 -e 传入覆盖
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    MCP_TRANSPORT="stdio" \
    MCP_HOST="0.0.0.0" \
    MCP_PORT="8090"

WORKDIR /app

# 优先复制依赖文件以利用 Docker 缓存层
COPY requirements.txt .

# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制其余源代码
COPY . .

# 创建下载目录
RUN mkdir -p /app/downloads

# 暴露 SSE 服务端口 (8090)
EXPOSE 8090

# 启动 MCP 服务端 (通过环境变量 MCP_TRANSPORT 控制 stdio 或 sse，默认 stdio)
CMD ["python", "pubmed_server.py"]

