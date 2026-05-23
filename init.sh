#!/bin/bash
# init.sh - 一键安装 llama.cpp 并下载所有 Qwen3.5 模型（含视觉配置）

set -e

MODEL_DIR="./models"
MODEL_SIZES=("0.8B" "2B" "4B" "9B")

echo "🚀 初始化 Local LLM Service"
echo "================================"

# 1. 安装 llama.cpp
if ! command -v llama-server &> /dev/null; then
    echo "📦 安装 llama.cpp..."
    if ! command -v brew &> /dev/null; then
        echo "   安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew install llama.cpp
    echo "✅ llama.cpp 安装完成"
else
    echo "✅ llama.cpp 已安装 ($(llama-server --version | head -1))"
fi

# 2. 安装下载工具
echo ""
echo "📦 准备下载工具..."

# 修复 macOS Python SSL 证书问题
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   🔧 修复 macOS Python SSL 证书..."
    if [ -f "/Applications/Python 3.*/Install Certificates.command" ]; then
        find /Applications -name "Install Certificates.command" -type f | head -1 | while read cert_script; do
            bash "$cert_script" 2>/dev/null || true
        done
    fi
fi

# 安装 aria2 (hfd 依赖)
if ! command -v aria2c &> /dev/null; then
    echo "   安装 aria2 (多线程下载工具)..."
    if command -v brew &> /dev/null; then
        brew install aria2
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y aria2
    fi
    echo "   ✅ aria2 安装完成"
else
    echo "   ✅ aria2 已安装"
fi

# 安装 hfd (HuggingFace Downloader)
echo "   安装 hfd..."
curl -sLf https://hf-mirror.com/hfd/hfd.sh > /tmp/hfd.sh && chmod +x /tmp/hfd.sh
mv /tmp/hfd.sh ./hfd.sh
echo "   ✅ hfd 安装完成"

# 3. 下载所有模型（含视觉配置文件）
echo ""
echo "📥 开始下载所有 Qwen3.5 模型（含视觉配置）..."

# 检查并提示代理设置
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
    echo "✅ 检测到代理设置"
else
    echo "⚠️  未检测到代理，如果下载很慢请设置："
    echo "   export https_proxy=http://127.0.0.1:7890"
    echo "   export http_proxy=http://127.0.0.1:7890"
fi

# 清除 all_proxy（aria2c 不支持 socks5 格式的 all_proxy）
unset all_proxy
unset ALL_PROXY

if [ -n "$HF_ENDPOINT" ]; then
    echo "🌐 镜像源: $HF_ENDPOINT"
else
    echo "🌐 使用官方源"
fi
echo ""

for SIZE in "${MODEL_SIZES[@]}"; do
    REPO="unsloth/Qwen3.5-${SIZE}-GGUF"
    MODEL_PATH="$MODEL_DIR/Qwen3.5-${SIZE}"
    
    echo "----------------------------------------"
    echo "📦 下载 Qwen3.5-${SIZE}..."
    mkdir -p "$MODEL_PATH"
    
    # 检查文件是否已完整下载（无未完成的 aria2 下载残留）
    HAS_INCOMPLETE=$(ls "$MODEL_PATH"/*.aria2 2>/dev/null | wc -l | tr -d ' ')
    if [ -f "$MODEL_PATH/Qwen3.5-${SIZE}-Q4_K_M.gguf" ] && \
       [ -f "$MODEL_PATH/mmproj-F16.gguf" ] && \
       [ "$HAS_INCOMPLETE" -eq 0 ]; then
        echo "✅ Qwen3.5-${SIZE} 已完整下载，跳过"
        continue
    fi

    # 存在未完成的下载 → 清除缓存后断点续传
    if [ "$HAS_INCOMPLETE" -gt 0 ]; then
        echo "⚠️  检测到未完成的下载，将断点续传..."
        rm -rf "$MODEL_PATH/.hfd"
    fi
    
    # 使用 hfd + aria2 下载（最优参数）
    # -x 10: 每个文件最大 10 个连接线程
    # -j 5: 同时下载 5 个文件（并发任务数）
    ./hfd.sh "$REPO" --tool aria2c -x 10 -j 5 --local-dir "$MODEL_PATH" \
        --include "Qwen3.5-${SIZE}-Q4_K_M.gguf" "mmproj-F16.gguf"
    
    # 验证文件是否存在
    if [ -f "$MODEL_PATH/Qwen3.5-${SIZE}-Q4_K_M.gguf" ] && [ -f "$MODEL_PATH/mmproj-F16.gguf" ]; then
        echo "✅ Qwen3.5-${SIZE} 下载完成"
    else
        echo "❌ Qwen3.5-${SIZE} 下载不完整，请检查网络"
        ls -lh "$MODEL_PATH/" 2>/dev/null || true
        exit 1
    fi
    echo ""
done

echo "================================"
echo "✅ 所有模型下载完成！"
echo "================================"
echo ""
echo "已下载的模型："
for SIZE in "${MODEL_SIZES[@]}"; do
    echo "  📁 Qwen3.5-${SIZE}: $MODEL_DIR/Qwen3.5-${SIZE}/"
done
echo ""
echo "运行服务: ./run.sh"
echo "提示: run.sh 使用路由模式，自动发现所有模型"
