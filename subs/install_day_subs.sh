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
TEMP_VENV="/tmp/temp_venv"
CRON_JOB="0 * * * * cd $INSTALL_DIR && $VENV_DIR/bin/python day_subs.py --github-upload >> $INSTALL_DIR/cron.log 2>&1"
CRON_COMMENT="# day_subs 自动更新订阅"
ZIP_PASSWORD="ds20250520"  # 预设密码

# 检查必要的命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: $1 未安装。请安装后再试。${NC}"
        echo "可以使用命令: sudo apt-get install $2"
        return 1
    fi
    return 0
}

# 检查Python venv模块是否可用
check_python_venv() {
    if ! python3 -m venv --help &> /dev/null; then
        echo -e "${RED}错误: Python3 venv模块未安装。请安装后再试。${NC}"
        echo "可以使用命令: sudo apt-get install python3-venv python3-full"
        return 1
    fi
    return 0
}

# 在临时虚拟环境中安装并使用pyzipper解压文件
setup_temp_venv_and_extract() {
    local zip_file=$1
    local extract_dir=$2
    local password=$3
    
    echo -e "${YELLOW}创建临时Python环境并安装pyzipper...${NC}"
    
    # 检查是否存在旧的临时环境并删除
    if [ -d "$TEMP_VENV" ]; then
        rm -rf "$TEMP_VENV"
    fi
    
    # 创建临时虚拟环境
    python3 -m venv "$TEMP_VENV"
    if [ $? -ne 0 ]; then
        echo -e "${RED}创建临时虚拟环境失败${NC}"
        return 1
    fi
    
    # 激活临时环境并安装pyzipper
    source "$TEMP_VENV/bin/activate"
    pip install --upgrade pip > /dev/null 2>&1
    echo -e "${YELLOW}在虚拟环境中安装pyzipper...${NC}"
    pip install pyzipper > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}在虚拟环境中安装pyzipper失败${NC}"
        deactivate
        rm -rf "$TEMP_VENV"
        return 1
    fi
    
    # 使用Python和pyzipper解压文件
    echo -e "${YELLOW}解压文件...${NC}"
    python - << EOF
import pyzipper
import os
import sys

try:
    # 创建目标目录
    os.makedirs("$extract_dir", exist_ok=True)
    
    # 使用pyzipper解压
    with pyzipper.AESZipFile("$zip_file") as zipf:
        zipf.pwd = b"$password"
        zipf.extractall("$extract_dir")
    
    print("文件已成功解压")
    sys.exit(0)
except Exception as e:
    print(f"解压失败: {e}")
    sys.exit(1)
EOF
    
    local result=$?
    
    # 清理临时环境
    deactivate
    rm -rf "$TEMP_VENV"
    
    return $result
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}订阅链接更新工具安装脚本${NC}"
    echo "用法: $0"
    echo ""
    echo "此脚本将引导您完成安装、更新或删除订阅链接更新工具的过程。"
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
    check_command wget wget || return 1
    check_command python3 python3 || return 1
    
    # 检查Python venv模块
    check_python_venv || return 1
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 下载ZIP文件
    echo -e "${YELLOW}正在下载程序包...${NC}"
    wget -q --show-progress "$ZIP_URL" -O "$ZIP_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络连接或URL是否正确${NC}"
        return 1
    fi
    
    # 备份当前目录
    if [ -d "$INSTALL_DIR/backup" ]; then
        rm -rf "$INSTALL_DIR/backup"
    fi
    
    if [ -f "$INSTALL_DIR/day_subs.py" ]; then
        echo -e "${YELLOW}备份现有文件...${NC}"
        mkdir -p "$INSTALL_DIR/backup"
        cp "$INSTALL_DIR"/*.py "$INSTALL_DIR/backup/" 2>/dev/null
        cp "$INSTALL_DIR/config.json" "$INSTALL_DIR/backup/" 2>/dev/null
        cp "$INSTALL_DIR/requirements.txt" "$INSTALL_DIR/backup/" 2>/dev/null
    fi
    
    # 解压文件
    setup_temp_venv_and_extract "$ZIP_FILE" "$INSTALL_DIR" "$ZIP_PASSWORD"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}解压失败${NC}"
        # 如果有备份，恢复
        if [ -d "$INSTALL_DIR/backup" ]; then
            echo -e "${YELLOW}正在恢复备份...${NC}"
            cp "$INSTALL_DIR/backup"/* "$INSTALL_DIR/"
        fi
        return 1
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
    return 0
}

# 删除程序
remove_program() {
    echo -e "${YELLOW}正在删除定时任务...${NC}"
    remove_cron_job
    
    echo -e "${YELLOW}正在删除程序文件...${NC}"
    rm -rf "$INSTALL_DIR"
    
    echo -e "${GREEN}删除完成！${NC}"
    return 0
}

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}===== 订阅链接更新工具 =====${NC}"
    echo -e "1. ${GREEN}安装/更新${NC}"
    echo -e "2. ${RED}删除${NC}"
    echo -e "3. ${YELLOW}退出${NC}"
    echo ""
    echo -n "请选择操作 [1-3]: "
}

# 主函数
main() {
    # 显示菜单并获取用户选择
    show_menu
    read choice
    
    case "$choice" in
        1)
            install_program
            ;;
        2)
            echo -e "${YELLOW}确定要删除订阅链接更新工具吗? [y/N]${NC}"
            read confirm
            if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                remove_program
            else
                echo -e "${BLUE}操作已取消${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}退出程序${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新运行脚本${NC}"
            exit 1
            ;;
    esac
}

# 执行主函数
main 