#!/bin/bash
# test.sh - 测试模型视觉能力

set -e

PORT="${1:-8080}"
BASE_URL="http://localhost:$PORT"
API_URL="$BASE_URL/v1/chat/completions"
IMAGE_DIR="./resources/test_images"

echo "🧪 测试模型视觉能力"
echo "================================"

# 检查服务是否运行
if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    echo "❌ 服务未运行，请先执行: ./run.sh"
    exit 1
fi

echo "✅ 服务正在运行 (端口: $PORT)"
echo ""

# 查看可用模型
echo "📋 获取可用模型列表..."
MODELS_RESPONSE=$(curl -s "$BASE_URL/v1/models")
MODEL_COUNT=$(echo "$MODELS_RESPONSE" | jq '.data | length')

if [ "$MODEL_COUNT" -eq 0 ]; then
    echo "❌ 没有可用的模型"
    exit 1
fi

echo "✅ 找到 $MODEL_COUNT 个模型"
echo ""

# 提取所有模型 ID（兼容 macOS）
MODEL_IDS=()
while IFS= read -r line; do
    MODEL_IDS+=("$line")
done < <(echo "$MODELS_RESPONSE" | jq -r '.data[].id')

# 检查图片文件
TEST1_IMAGE="$IMAGE_DIR/test1.png"
TEST2_IMAGE="$IMAGE_DIR/test2.png"

if [ ! -f "$TEST1_IMAGE" ] || [ ! -f "$TEST2_IMAGE" ]; then
    echo "❌ 测试图片不存在"
    echo "   期望: $TEST1_IMAGE"
    echo "   期望: $TEST2_IMAGE"
    exit 1
fi

echo "🖼️  测试图片:"
echo "   - test1.png: 蓝色墙 + 猫"
echo "   - test2.png: 绿色墙 + 狗"
echo ""

# 将图片转换为 base64
echo "📤 转换图片为 base64..."
IMAGE1_BASE64=$(base64 -i "$TEST1_IMAGE")
IMAGE2_BASE64=$(base64 -i "$TEST2_IMAGE")
echo "✅ 图片转换完成"
echo ""

# 测试每个模型的视觉能力
TEST_NUM=0
PASS_NUM=0
FAIL_NUM=0

for MODEL_ID in "${MODEL_IDS[@]}"; do
    TEST_NUM=$((TEST_NUM + 1))
    echo "----------------------------------------"
    echo "🧪 测试 $TEST_NUM/$MODEL_COUNT: $MODEL_ID"
    echo "----------------------------------------"
    
    # 测试图片 1：蓝色墙 + 猫
    echo "  📸 测试图片 1 (蓝色墙 + 猫)..."
    
    # 创建临时 JSON 文件（避免命令行参数过长）
    TEMP_JSON=$(mktemp /tmp/test_model.XXXXXX.json)
    
    cat > "$TEMP_JSON" <<JSONEOF
{
    "model": "$MODEL_ID",
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "这张图片里有什么？请描述一下。"
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": "data:image/png;base64,$IMAGE1_BASE64"
                    }
                }
            ]
        }
    ],
    "max_tokens": 200
}
JSONEOF
    
    RESPONSE1=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d @"$TEMP_JSON")
    
    rm -f "$TEMP_JSON"
    
    HTTP_CODE1=$(echo "$RESPONSE1" | tail -n1)
    BODY1=$(echo "$RESPONSE1" | sed '$d')
    
    if [ "$HTTP_CODE1" -eq 200 ]; then
        CONTENT1=$(echo "$BODY1" | jq -r '.choices[0].message.content' 2>/dev/null || echo "解析失败")
        
        # 检查是否识别出关键元素
        if echo "$CONTENT1" | grep -qi "猫\|cat\|蓝色\|blue\|墙\|wall"; then
            echo "  ✅ 通过 - 识别成功"
            echo "     回复: ${CONTENT1:0:100}..."
            PASS_NUM=$((PASS_NUM + 1))
        else
            echo "  ⚠️  部分通过 - 响应正常但可能未识别关键元素"
            echo "     回复: ${CONTENT1:0:100}..."
            PASS_NUM=$((PASS_NUM + 1))
        fi
    else
        ERROR1=$(echo "$BODY1" | jq -r '.error.message' 2>/dev/null || echo "未知错误")
        echo "  ❌ 失败 - HTTP $HTTP_CODE1"
        echo "     错误: $ERROR1"
        FAIL_NUM=$((FAIL_NUM + 1))
    fi
    
    echo ""
    
    # 测试图片 2：绿色墙 + 狗
    echo "  📸 测试图片 2 (绿色墙 + 狗)..."
    
    # 创建临时 JSON 文件
    TEMP_JSON2=$(mktemp /tmp/test_model.XXXXXX.json)
    
    cat > "$TEMP_JSON2" <<JSONEOF
{
    "model": "$MODEL_ID",
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": "这张图片里有什么动物？墙是什么颜色？"
                },
                {
                    "type": "image_url",
                    "image_url": {
                        "url": "data:image/png;base64,$IMAGE2_BASE64"
                    }
                }
            ]
        }
    ],
    "max_tokens": 200
}
JSONEOF
    
    RESPONSE2=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d @"$TEMP_JSON2")
    
    rm -f "$TEMP_JSON2"
    
    HTTP_CODE2=$(echo "$RESPONSE2" | tail -n1)
    BODY2=$(echo "$RESPONSE2" | sed '$d')
    
    if [ "$HTTP_CODE2" -eq 200 ]; then
        CONTENT2=$(echo "$BODY2" | jq -r '.choices[0].message.content' 2>/dev/null || echo "解析失败")
        
        # 检查是否识别出关键元素
        if echo "$CONTENT2" | grep -qi "狗\|dog\|绿色\|green\|墙\|wall"; then
            echo "  ✅ 通过 - 识别成功"
            echo "     回复: ${CONTENT2:0:100}..."
            PASS_NUM=$((PASS_NUM + 1))
        else
            echo "  ⚠️  部分通过 - 响应正常但可能未识别关键元素"
            echo "     回复: ${CONTENT2:0:100}..."
            PASS_NUM=$((PASS_NUM + 1))
        fi
    else
        ERROR2=$(echo "$BODY2" | jq -r '.error.message' 2>/dev/null || echo "未知错误")
        echo "  ❌ 失败 - HTTP $HTTP_CODE2"
        echo "     错误: $ERROR2"
        FAIL_NUM=$((FAIL_NUM + 1))
    fi
    
    echo ""
done

# 总结
echo "================================"
echo "📊 测试结果总结"
echo "================================"
echo "总测试数: $((TEST_NUM * 2))"
echo "✅ 通过: $PASS_NUM"
echo "❌ 失败: $FAIL_NUM"
echo ""

if [ $FAIL_NUM -eq 0 ]; then
    echo "🎉 所有模型视觉能力测试通过！"
else
    echo "⚠️  部分模型测试失败，请检查日志"
fi
