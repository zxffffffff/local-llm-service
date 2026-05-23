#!/bin/bash
# fix-ssl.sh - 修复 macOS Python SSL 证书问题

echo "🔧 修复 macOS Python SSL 证书"
echo "================================"

# 检查系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  此脚本仅适用于 macOS"
    exit 1
fi

# 方法 1: 使用 Python 自带的证书安装脚本
echo ""
echo "方法 1: 安装 Python 证书..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)

if [ -f "/Applications/Python ${PYTHON_VERSION}/Install Certificates.command" ]; then
    echo "   找到证书安装脚本，正在执行..."
    bash "/Applications/Python ${PYTHON_VERSION}/Install Certificates.command"
    echo "   ✅ 证书安装完成"
else
    echo "   ⚠️  未找到自动安装脚本，尝试手动安装..."
    
    # 方法 2: 使用 certifi
    echo ""
    echo "方法 2: 使用 certifi 包..."
    pip3 install --trusted-host pypi.org --trusted-host files.pythonhosted.org certifi
    
    # 设置环境变量
    CERT_PATH=$(python3 -c "import certifi; print(certifi.where())" 2>/dev/null)
    if [ -n "$CERT_PATH" ]; then
        echo "   证书路径: $CERT_PATH"
        echo ""
        echo "请将以下内容添加到 ~/.zshrc:"
        echo "export SSL_CERT_FILE=$CERT_PATH"
        echo ""
        read -p "是否自动添加？(y/n): " add_cert
        if [ "$add_cert" = "y" ] || [ "$add_cert" = "Y" ]; then
            echo "export SSL_CERT_FILE=$CERT_PATH" >> ~/.zshrc
            echo "✅ 已添加到 ~/.zshrc"
            echo "请执行: source ~/.zshrc"
        fi
    fi
fi

echo ""
echo "================================"
echo "验证修复："
echo "================================"
echo ""
echo "测试 pip 连接..."
if pip3 list --trusted-host pypi.org 2>/dev/null | head -5; then
    echo "✅ pip 连接正常"
else
    echo "❌ pip 连接仍有问题"
fi

echo ""
echo "提示: 如果问题仍然存在，可以尝试："
echo "  1. 重新安装 Python: brew install python3"
echo "  2. 使用代理: export HTTPS_PROXY=http://127.0.0.1:7890"
echo "  3. 使用国内镜像: pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple <package>"
