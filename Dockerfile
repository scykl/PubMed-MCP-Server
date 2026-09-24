FROM python:3.11-slim

# 设置 Python 环境变量
# PYTHONUNBUFFERED=1: 禁止输出缓冲，确保 MCP stdio 消息实时发送
# PYTHONDONTWRITEBYTECODE=1: 避免生成 .pyc 文件
# NCBI_API_KEY: NCBI API 密钥，可在 docker run 时通过 -e 传入覆盖
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    NCBI_API_KEY=""

WORKDIR /app

# 优先复制依赖文件以利用 Docker 缓存层
COPY requirements.txt .

# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制其余源代码
COPY . .

# 启动 MCP 服务端 (stdio 传输模式)
CMD ["python", "pubmed_server.py"]

