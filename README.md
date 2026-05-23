# local-llm-service

在本地运行 llama.cpp server，通过 HuggingFace 下载开源模型。

## 🚀 快速开始

### 1. 初始化（安装 + 下载所有模型）

```bash
# 一键安装并下载全部 4 个 Qwen3.5 模型（含视觉配置）
./init.sh
```

**会自动下载：**
- ✅ Qwen3.5-0.8B (Q4_K_M + mmproj)
- ✅ Qwen3.5-2B (Q4_K_M + mmproj)
- ✅ Qwen3.5-4B (Q4_K_M + mmproj)
- ✅ Qwen3.5-9B (Q4_K_M + mmproj)

**🚀 加速下载：**

脚本已自动使用 `hfd` 多线程下载工具（基于 aria2c，10线程 + 5并发）。如果还是很慢：

```bash
# 方法 1: 设置代理（必须同时设置 http 和 https）
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
./init.sh

# 方法 2: 使用镜像源
export HF_ENDPOINT=https://hf-mirror.com
./init.sh

# 方法 3: 两者结合（最快）
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export HF_ENDPOINT=https://hf-mirror.com
./init.sh
```

**⚠️ 重要提示：**
- 必须同时设置 `http_proxy` 和 `https_proxy`（小写）
- hfd 工具会自动使用 10 线程并发下载，速度比官方 CLI 快 5-10 倍

### 2. 启动服务

```bash
# 使用默认端口 10101（路由模式，同时加载所有模型）
./run.sh

# 指定端口
./run.sh 3000
```

**路由模式特性：**
- ✅ 自动扫描 `./models` 目录下的所有 GGUF 模型
- ✅ 按需加载：首次请求时加载模型，后续热调用
- ✅ LRU淘汰：可配置最大并发模型数，超出时自动卸载最少使用的模型
- ✅ 进程隔离：每个模型独立进程，单个模型崩溃不影响其他模型
- ✅ 通过 API 的 `model` 参数动态选择模型（**直接用目录名**，如 `Qwen3.5-0.8B`）

### 3. 测试视觉能力

```bash
# 运行视觉测试（默认端口 10101）
./test.sh

# 指定端口
./test.sh 3000
```

**测试内容：**
- ✅ 自动检测所有可用模型
- ✅ 测试两张图片：蓝色墙+猫、绿色墙+狗
- ✅ 验证模型是否能正确识别图像内容
- ✅ 生成测试报告

### 4. 使用 API

服务启动后访问：
- API 文档: http://localhost:10101/docs
- OpenAI 兼容接口: http://localhost:10101/v1/chat/completions

## 📝 示例

### 基本使用

```bash
# 首次使用：初始化并下载所有模型
./init.sh

# 启动服务（路由模式）
./run.sh

# 测试视觉能力
./test.sh
```

### API 测试

**查看可用模型：**

```bash
curl http://localhost:10101/v1/models
```

**测试不同模型：**

路由模式下，`model` 字段直接使用目录名（短名称），无需完整路径。

```bash
# 使用 0.8B 模型
curl http://localhost:10101/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.5-0.8B",
    "messages": [{"role": "user", "content": "你好！"}]
  }'

# 使用 2B 模型
curl http://localhost:10101/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.5-2B",
    "messages": [{"role": "user", "content": "介绍一下你自己"}]
  }'

# 使用 4B 模型
curl http://localhost:10101/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.5-4B",
    "messages": [{"role": "user", "content": "写一首诗"}]
  }'

# 使用 9B 模型
curl http://localhost:10101/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.5-9B",
    "messages": [{"role": "user", "content": "解释量子计算"}]
  }'
```

**批量测试对比：**

```bash
#!/bin/bash
# test-models.sh - 批量测试所有模型

MODELS=(
  "Qwen3.5-0.8B"
  "Qwen3.5-2B"
  "Qwen3.5-4B"
  "Qwen3.5-9B"
)
PROMPT="请用一句话介绍人工智能"

for MODEL in "${MODELS[@]}"; do
    echo "\n🧪 测试 $MODEL..."
    time curl -s http://localhost:10101/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}]}" \
        | jq -r '.choices[0].message.content'
done
```

## 🔧 技术栈

- **推理引擎**: [llama.cpp](https://github.com/ggml-org/llama.cpp)
- **模型格式**: GGUF (Q4_K_M 量化)
- **视觉支持**: mmproj 多模态投影文件
- **模型来源**: [Unsloth Qwen3.5 GGUF](https://huggingface.co/unsloth)
- **支持平台**: macOS (Apple Silicon)
- **多模态能力**: 文本 + 图像理解

## 💡 提示

- 首次运行 `./init.sh` 会自动安装 Homebrew、llama.cpp 和 hfd + aria2c 下载工具
- 模型默认下载到 `./models` 目录，每个模型包含 GGUF + mmproj 文件
- Qwen3.5 是原生多模态模型，支持文本和图像输入
- `run.sh` 使用路由模式，自动扫描 `./models` 目录
- 通过 API 的 `model` 参数动态选择要使用的模型（直接用目录名，如 `Qwen3.5-0.8B`）
- 查看可用模型列表：`curl http://localhost:10101/v1/models`
- 使用 `./test.sh` 测试模型的视觉能力
- **macOS SSL 错误**: 如果遇到 SSL 证书错误，运行 `./fix-ssl.sh` 修复
- 按 `Ctrl+C` 停止服务

## ❓ 常见问题

### 1. SSL 证书错误

**错误信息：**
```
SSLCertVerificationError: certificate verify failed
```

**解决方案：**
```bash
# 运行修复脚本
./fix-ssl.sh

# 或者手动修复
pip3 install --trusted-host pypi.org --trusted-host files.pythonhosted.org certifi
```

### 2. 下载速度慢

见上方「🚀 加速下载」章节。

### 3. 模型加载失败

检查模型文件是否完整：
```bash
ls -lh ./models/Qwen3.5-*/
```

确保每个模型目录包含：
- `Qwen3.5-{SIZE}-Q4_K_M.gguf` (主模型)
- `mmproj-F16.gguf` (视觉投影)
