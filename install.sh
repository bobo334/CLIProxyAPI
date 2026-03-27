#!/usr/bin/env bash
#
# install.sh - CLI Proxy API 一键安装脚本
#
# 本脚本自动化完成以下操作：
# 1. 检查系统依赖（Docker、Docker Compose、Git）
# 2. 克隆或更新代码仓库
# 3. 创建配置文件
# 4. 启动服务
#
# 用法: curl -fsSL https://raw.githubusercontent.com/router-for-me/cli-proxy-api/main/install.sh | bash
# 或：wget -qO- https://raw.githubusercontent.com/router-for-me/cli-proxy-api/main/install.sh | bash

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 运行（可选，根据需求调整）
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "建议以 root 权限运行此脚本以获得最佳体验"
    fi
}

# 检查并安装 Docker
check_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker 已安装：$(docker --version)"
        return 0
    else
        log_warn "Docker 未安装，正在尝试安装..."
        install_docker
    fi
}

install_docker() {
    # 先清理可能存在的错误 Docker 源（特别是 trixie 相关的 Ubuntu 源）
    log_info "检查并清理错误的 Docker 源配置..."
    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        if grep -q "trixie" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
            log_warn "检测到错误的 trixie 源配置，正在备份并删除..."
            cp /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.list.bak.$(date +%s)
            rm -f /etc/apt/sources.list.d/docker.list
        fi
    fi
    # 清理其他可能的错误源文件
    rm -f /etc/apt/sources.list.d/download_docker_com_linux_ubuntu.list 2>/dev/null || true
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        log_info "检测到 Debian/Ubuntu 系统，正在安装 Docker..."
        
        # 检测具体发行版
        if [ -f /etc/debian_version ]; then
            # Debian 系统
            log_info "检测到 Debian 系统"
            apt-get update -qq
            apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            # Ubuntu 系统
            log_info "检测到 Ubuntu 系统"
            apt-get update -qq
            apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi
        
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        log_info "检测到 CentOS/RHEL 系统，正在安装 Docker..."
        yum install -y -q yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y -q docker-ce docker-ce-cli containerd.io
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        log_info "检测到 Arch Linux 系统，正在安装 Docker..."
        pacman -Sy --noconfirm docker
    else
        log_error "不支持的操作系统，请手动安装 Docker"
        exit 1
    fi
    
    systemctl start docker
    systemctl enable docker
    log_success "Docker 安装完成"
}

# 检查并安装 Docker Compose
check_docker_compose() {
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        log_success "Docker Compose 已安装"
        return 0
    else
        log_warn "Docker Compose 未安装，正在尝试安装..."
        install_docker_compose
    fi
}

install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        return 0
    fi
    
    DC_VERSION="v2.24.0"
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) log_error "不支持的架构：$ARCH"; exit 1 ;;
    esac
    
    curl -L "https://github.com/docker/compose/releases/download/${DC_VERSION}/docker-compose-linux-${ARCH}" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose 安装完成"
}

# 检查 Git
check_git() {
    if command -v git &> /dev/null; then
        log_success "Git 已安装：$(git --version)"
        return 0
    else
        log_warn "Git 未安装，正在尝试安装..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y -qq git
        elif command -v yum &> /dev/null; then
            yum install -y -q git
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm git
        else
            log_error "无法安装 Git，请手动安装"
            exit 1
        fi
        log_success "Git 安装完成"
    fi
}

# 克隆或更新仓库（从 GitHub Release 下载最新版）
setup_repository() {
    local REPO_OWNER="router-for-me"
    local REPO_NAME="CLIProxyAPI"
    local INSTALL_DIR="/opt/cli-proxy-api"
    
    log_info "正在获取最新 release 版本..."
    
    # 从 GitHub API 获取最新版本号
    local LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$LATEST_RELEASE" ]]; then
        log_warn "无法获取最新版本号，尝试使用 main 分支压缩包"
        LATEST_RELEASE="main"
        local DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/main.tar.gz"
    else
        local DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/${LATEST_RELEASE}.tar.gz"
    fi
    
    log_info "最新版本：${LATEST_RELEASE}"
    log_info "下载地址：${DOWNLOAD_URL}"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "检测到已存在的安装，正在更新到最新版本..."
        # 备份配置文件
        if [[ -f "$INSTALL_DIR/config.yaml" ]]; then
            cp "$INSTALL_DIR/config.yaml" /tmp/config.yaml.bak
            log_info "已备份配置文件"
        fi
        
        # 删除旧目录并重新下载
        rm -rf "$INSTALL_DIR"
    else
        log_info "正在下载安装包..."
    fi
    
    # 创建临时目录下载
    local TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # 下载并解压
    curl -fsSL "$DOWNLOAD_URL" -o "${TEMP_DIR}/source.tar.gz"
    tar -xzf "${TEMP_DIR}/source.tar.gz"
    
    # 移动文件到安装目录（GitHub 压缩包会多一层目录）
    local EXTRACTED_DIR=$(ls -1 | grep "^${REPO_NAME}" | head -n1)
    mv "$EXTRACTED_DIR" "$INSTALL_DIR"
    
    # 清理临时文件
    cd /
    rm -rf "$TEMP_DIR"
    
    # 恢复配置文件
    if [[ -f /tmp/config.yaml.bak ]]; then
        cp /tmp/config.yaml.bak "$INSTALL_DIR/config.yaml"
        rm /tmp/config.yaml.bak
        log_info "已恢复配置文件"
    fi
    
    log_success "仓库安装/更新完成"
}

# 创建配置文件
setup_config() {
    local CONFIG_FILE="/opt/cli-proxy-api/config.yaml"
    local EXAMPLE_CONFIG="/opt/cli-proxy-api/config.example.yaml"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "正在创建配置文件..."
        cp "$EXAMPLE_CONFIG" "$CONFIG_FILE"
        
        # 生成随机 API 密钥
        local API_KEY=$(openssl rand -hex 16)
        sed -i "s/your-api-key-1/${API_KEY}/" "$CONFIG_FILE"
        sed -i 's/your-api-key-2/your-second-api-key/' "$CONFIG_FILE"
        sed -i 's/your-api-key-3/your-third-api-key/' "$CONFIG_FILE"
        
        log_success "配置文件创建完成"
        log_info "您的 API 密钥：${API_KEY}"
        echo -e "${YELLOW}请妥善保管此密钥！${NC}"
    else
        log_info "配置文件已存在，跳过创建"
    fi
}

# 创建必要的目录
setup_directories() {
    log_info "创建必要的目录..."
    mkdir -p /opt/cli-proxy-api/logs
    mkdir -p /root/.cli-proxy-api
    log_success "目录创建完成"
}

# 启动服务
start_service() {
    cd /opt/cli-proxy-api
    
    log_info "正在启动 Docker 容器..."
    
    # 使用 docker compose 或 docker-compose
    if docker compose version &> /dev/null 2>&1; then
        docker compose up -d --remove-orphans
    else
        docker-compose up -d --remove-orphans
    fi
    
    log_success "服务启动命令已执行"
    log_info "查看日志：docker compose logs -f"
    log_info "停止服务：docker compose down"
}

# 显示安装信息
show_info() {
    echo ""
    echo "========================================"
    echo -e "${GREEN}CLI Proxy API 安装完成！${NC}"
    echo "========================================"
    echo ""
    echo "服务状态检查："
    echo "  docker compose ps"
    echo ""
    echo "查看实时日志："
    echo "  docker compose logs -f"
    echo ""
    echo "访问管理面板："
    echo "  http://localhost:8317"
    echo ""
    echo "API 端点："
    echo "  http://localhost:8317/v1/chat/completions"
    echo ""
    echo "配置文件位置："
    echo "  /opt/cli-proxy-api/config.yaml"
    echo ""
    echo "认证目录："
    echo "  /root/.cli-proxy-api"
    echo ""
    echo -e "${YELLOW}重要提示：${NC}"
    echo "1. 请修改 config.yaml 中的默认 API 密钥"
    echo "2. 如需外网访问，请配置防火墙规则"
    echo "3. 生产环境建议启用 TLS"
    echo ""
}

# 主函数
main() {
    echo ""
    echo "========================================"
    echo "  CLI Proxy API 一键安装脚本"
    echo "========================================"
    echo ""
    
    check_root
    # 不再需要 Git，因为直接从 Release 下载
    check_docker
    check_docker_compose
    setup_repository
    setup_directories
    setup_config
    start_service
    show_info
    
    log_success "安装完成！"
}

# 执行主函数
main "$@"
