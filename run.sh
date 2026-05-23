#!/bin/bash
# run.sh - 启动 llama-server 路由模式（同时加载多个模型）

set -e

MODEL_DIR="./models"
PORT="${1:-8080}"
CONTEXT_SIZE=8192
MAX_MODELS=0  # 0 = 不限制同时加载的模型数量

echo "🚀 启动 Local LLM Service (路由模式)"
echo "================================"

# 检查 llama-server
if ! command -v llama-server &> /dev/null; then
    echo "❌ llama-server 未安装，请先运行: ./init.sh"
    exit 1
fi

# 检查模型目录
if [ ! -d "$MODEL_DIR" ]; then
    echo "❌ 模型目录不存在，请先运行: ./init.sh"
    exit 1
fi

echo "📂 模型目录: $MODEL_DIR"
echo "🌐 端口: $PORT"
echo "📝 上下文: $CONTEXT_SIZE"
echo "🔢 最大并发模型数: $MAX_MODELS (0=无限制)"
echo "================================"
echo ""
echo "📡 API 端点:"
echo "  - API 文档: http://localhost:$PORT/docs"
echo "  - OpenAI 兼容: http://localhost:$PORT/v1/chat/completions"
echo "  - 模型列表: http://localhost:$PORT/v1/models"
echo "  - 健康检查: http://localhost:$PORT/health"
echo ""
echo "💡 使用示例:"
echo "  # 查看可用模型"
echo "  curl http://localhost:$PORT/v1/models"
echo ""
echo "  # 文本对话 (用目录名作为 model，无需长路径)"
echo "  curl http://localhost:$PORT/v1/chat/completions \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"
echo "      \"model\": \"Qwen3.5-0.8B\",\"
echo "      \"messages\": [{\"role\": \"user\", \"content\": \"你好！\"}]\"
echo "    }'"
echo ""
echo "💡 提示: 路由模式下模型按需加载，目录名即为 model 名称"
echo "按 Ctrl+C 停止服务"
echo ""

# 启动服务器（路由模式）
# 路由模式特点：
# 1. 不指定 -m 参数，启用自动发现
# 2. --models-dir 指定模型目录
# 3. --models-max 限制同时驻留内存的模型数量（默认4，0=无限制）
# 4. 按需加载：首次请求时加载模型，后续热调用
# 5. LRU淘汰：超出限制时自动卸载最近最少使用的模型
exec llama-server \
    --models-dir "$MODEL_DIR" \
    --models-max "$MAX_MODELS" \
    --port "$PORT" \
    --ctx-size "$CONTEXT_SIZE" \
    --host 0.0.0.0
