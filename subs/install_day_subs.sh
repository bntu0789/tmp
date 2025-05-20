#!/bin/bash

# 订阅链接更新工具安装/更新/删除脚本
# 适用于Debian系统

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 配置
INSTALL_DIR="$HOME/day_subs"
VENV_DIR="$INSTALL_DIR/venv"
ZIP_URL="https://raw.githubusercontent.com/bntu0789/tmp/main/subs/day_sub.zip"
ZIP_FILE="/tmp/day_sub.zip"
CRON_JOB="0 * * * * cd $INSTALL_DIR && $VENV_DIR/bin/python day_subs.py --github-upload >> $INSTALL_DIR/cron.log 2>&1"
CRON_COMMENT="# day_subs 自动更新订阅"

# 检查必要的命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: $1 未安装。请安装后再试。${NC}"
        echo "可以使用命令: sudo apt-get install $2"
        exit 1
    fi
}

# 检查Python venv模块是否可用
check_python_venv() {
    if ! python3 -m venv --help &> /dev/null; then
        echo -e "${RED}错误: Python3 venv模块未安装。请安装后再试。${NC}"
        echo "可以使用命令: sudo apt-get install python3-venv"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}订阅链接更新工具安装脚本${NC}"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  install    安装或更新程序"
    echo "  remove     删除程序和定时任务"
    echo "  help       显示此帮助信息"
    echo ""
}

# 检查是否已安装cron任务
check_cron_installed() {
    crontab -l 2>/dev/null | grep -q "$CRON_COMMENT"
    return $?
}

# 添加cron任务
add_cron_job() {
    (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT"; echo "$CRON_JOB $CRON_COMMENT") | crontab -
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}已添加定时任务，每小时运行一次${NC}"
    else
        echo -e "${RED}添加定时任务失败${NC}"
        return 1
    fi
}

# 删除cron任务
remove_cron_job() {
    if check_cron_installed; then
        crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" | crontab -
        echo -e "${GREEN}已删除定时任务${NC}"
    else
        echo -e "${YELLOW}未找到相关定时任务${NC}"
    fi
}

# 安装程序
install_program() {
    echo -e "${BLUE}开始安装订阅链接更新工具...${NC}"
    
    # 检查必要的命令
    check_command wget wget
    check_command unzip unzip
    check_command python3 python3
    # 检查Python venv模块
    check_python_venv
    check_command pip3 python3-pip
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 下载ZIP文件
    echo -e "${YELLOW}正在下载程序包...${NC}"
    wget -q --show-progress "$ZIP_URL" -O "$ZIP_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络连接或URL是否正确${NC}"
        exit 1
    fi
    
    # 提示输入密码
    echo -e "${YELLOW}请输入ZIP文件密码:${NC}"
    read -s ZIP_PASSWORD
    
    # 解压文件
    echo -e "${YELLOW}正在解压文件...${NC}"
    # 备份当前目录
    if [ -d "$INSTALL_DIR/backup" ]; then
        rm -rf "$INSTALL_DIR/backup"
    fi
    
    if [ -f "$INSTALL_DIR/day_subs.py" ]; then
        mkdir -p "$INSTALL_DIR/backup"
        cp "$INSTALL_DIR"/*.py "$INSTALL_DIR/backup/" 2>/dev/null
        cp "$INSTALL_DIR/config.json" "$INSTALL_DIR/backup/" 2>/dev/null
        cp "$INSTALL_DIR/requirements.txt" "$INSTALL_DIR/backup/" 2>/dev/null
    fi
    
    # 使用unzip解压并提供密码
    unzip -o -P "$ZIP_PASSWORD" "$ZIP_FILE" -d "$INSTALL_DIR"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}解压失败，可能是密码错误${NC}"
        # 如果有备份，恢复
        if [ -d "$INSTALL_DIR/backup" ]; then
            echo -e "${YELLOW}正在恢复备份...${NC}"
            cp "$INSTALL_DIR/backup"/* "$INSTALL_DIR/"
        fi
        exit 1
    fi
    
    # 创建虚拟环境
    echo -e "${YELLOW}正在创建Python虚拟环境...${NC}"
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    
    # 激活虚拟环境并安装依赖
    echo -e "${YELLOW}正在安装依赖...${NC}"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$INSTALL_DIR/requirements.txt"
    
    # 添加定时任务
    echo -e "${YELLOW}正在设置定时任务...${NC}"
    add_cron_job
    
    # 清理临时文件
    rm -f "$ZIP_FILE"
    
    echo -e "${GREEN}安装完成！${NC}"
    echo -e "程序安装在: ${BLUE}$INSTALL_DIR${NC}"
    echo -e "可以手动运行: ${BLUE}cd $INSTALL_DIR && $VENV_DIR/bin/python day_subs.py${NC}"
}

# 删除程序
remove_program() {
    echo -e "${YELLOW}确定要删除订阅链接更新工具吗? [y/N]${NC}"
    read confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo -e "${YELLOW}正在删除定时任务...${NC}"
        remove_cron_job
        
        echo -e "${YELLOW}正在删除程序文件...${NC}"
        rm -rf "$INSTALL_DIR"
        
        echo -e "${GREEN}删除完成！${NC}"
    else
        echo -e "${BLUE}操作已取消${NC}"
    fi
}

# 主函数
main() {
    # 如果没有参数，显示帮助
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    # 处理参数
    case "$1" in
        install)
            install_program
            ;;
        remove)
            remove_program
            ;;
        help)
            show_help
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 