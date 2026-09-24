#!/usr/bin/env bash
# ==============================================================================
# PubMed-MCP-Server VPS 一键部署脚本
# 支持系统: Ubuntu / Debian / CentOS / Rocky / AlmaLinux
# ==============================================================================

set -euo pipefail

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 1. 检查 root / sudo 权限
if [ "$(id -u)" -ne 0 ]; then
    error "请使用 root 用户或 sudo 执行此脚本！"
    exit 1
fi

REPO_URL="https://github.com/scykl/PubMed-MCP-Server.git"
INSTALL_DIR="/opt/pubmed-mcp-server"

info "================================================="
info "       PubMed-MCP-Server VPS 一键安装脚本        "
info "================================================="

# 2. 检查并安装基础依赖 (curl, git)
info "正在检查基础依赖 (curl, git)..."
if command -v apt-get &>/dev/null; then
    apt-get update -y && apt-get install -y curl git ca-certificates
elif command -v yum &>/dev/null; then
    yum install -y curl git ca-certificates
elif command -v dnf &>/dev/null; then
    dnf install -y curl git ca-certificates
fi

# 3. 检查并安装 Docker
if ! command -v docker &>/dev/null; then
    info "未检测到 Docker，正在通过官方脚本安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    success "Docker 安装完成！"
else
    info "检测到 Docker 已安装: $(docker --version)"
fi

# 检查并安装 Docker Compose 插件 (如果尚未安装)
if ! docker compose version &>/dev/null; then
    info "未检测到 docker compose 插件，正在尝试安装..."
    if command -v apt-get &>/dev/null; then
        apt-get install -y docker-compose-plugin || true
    fi
fi

# 4. 拉取或更新代码仓库
if [ -d "$INSTALL_DIR/.git" ]; then
    info "目标目录 $INSTALL_DIR 已存在，正在拉取最新代码..."
    cd "$INSTALL_DIR"
    git fetch --all
    git reset --hard origin/main
else
    info "正在克隆仓库到 $INSTALL_DIR ..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 创建下载目录
mkdir -p "$INSTALL_DIR/downloads"

# 5. 配置环境变量 (NCBI_API_KEY)
ENV_FILE="$INSTALL_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    info "配置环境变量..."
    # 优先读取传入的参数或环境变量
    NCBI_KEY="${NCBI_API_KEY:-}"
    if [ -z "$NCBI_KEY" ] && [ -e /dev/tty ]; then
        echo -e "${YELLOW}请输入您的 NCBI_API_KEY（可选，直接按回车可跳过）:${NC} "
        read -r input_key < /dev/tty 2>/dev/null || input_key=""
        NCBI_KEY="$input_key"
    fi

    cat > "$ENV_FILE" <<EOF
# NCBI API Key (申请地址: https://www.ncbi.nlm.nih.gov/account/settings/)
NCBI_API_KEY=${NCBI_KEY}
EOF
    success "已生成 .env 配置文件"
else
    info "检测到已有 .env 配置文件，跳过覆盖。"
fi

# 6. 构建 Docker 镜像
info "开始构建 Docker 镜像 (pubmed-mcp:latest)..."
docker build -t pubmed-mcp:latest .
success "Docker 镜像构建成功！"

# 7. 运行自检验证
info "正在验证镜像运行状态..."
docker run --rm --env-file "$ENV_FILE" pubmed-mcp:latest python -c "from pubmed_web_search import get_ncbi_api_key; from pubmed_server import mcp; print('Verification passed! FastMCP loaded successfully. API Key configured:', bool(get_ncbi_api_key()))"

echo ""
info "================================================="
success "        PubMed MCP Server 部署完成！            "
info "================================================="
echo -e "
${GREEN}常用操作指南:${NC}

1. ${YELLOW}以 HTTP/SSE 模式后台启动服务 (推荐，免配 SSH 密钥):${NC}
   cd $INSTALL_DIR
   docker compose up -d
   # 服务将常驻运行在 http://您的VPS_IP:8090/sse

2. ${YELLOW}进入项目目录查看日志:${NC}
   cd $INSTALL_DIR
   docker compose logs -f

3. ${YELLOW}单次交互式运行 (用于 stdio 模式本地测试):${NC}
   docker run -i --rm --env-file .env -v \$(pwd)/downloads:/app/downloads pubmed-mcp:latest

4. ${YELLOW}修改配置 (NCBI_API_KEY / 端口):${NC}
   nano $INSTALL_DIR/.env
   # 修改保存后重新运行即可生效

5. ${YELLOW}客户端配置 (HTTP/SSE 模式直连，无需 SSH 密钥):${NC}
   - Cursor: Type 选择 SSE，URL 填入 http://您的VPS_IP:8090/sse
   - Claude Desktop:
     {
       \"mcpServers\": {
         \"pubmed\": {
           \"type\": \"sse\",
           \"url\": \"http://您的VPS_IP:8090/sse\"
         }
       }
     }
"
