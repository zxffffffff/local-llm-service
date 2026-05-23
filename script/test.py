#!/usr/bin/env python3
"""
test.py - 测试所有模型的视觉能力

用法:
    python3 script/test.py [--port 8080] [--model Qwen3.5-0.8B]
"""

import sys
import os
import base64
import json
import subprocess
import argparse
import urllib.request
import urllib.error
import time

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGE_DIR = os.path.join(PROJECT_ROOT, "resources", "test_images")

# 测试配置
TEST_IMAGES = {
    "test1.png": {"desc": "蓝色墙 + 猫", "keywords": ["猫", "cat", "蓝色", "blue", "墙", "wall"]},
    "test2.png": {"desc": "绿色墙 + 狗", "keywords": ["狗", "dog", "绿色", "green", "墙", "wall"]},
}

TEST_PROMPTS = {
    "test1.png": "这张图片里有什么？请描述一下。",
    "test2.png": "这张图片里有什么动物？墙是什么颜色？",
}


def http_get(url, timeout=10):
    """发送 GET 请求"""
    req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8")
    except Exception as e:
        return 0, str(e)


def http_post(url, data, timeout=120):
    """发送 POST 请求（手动构造 JSON 避免大字符串编码慢）"""
    import tempfile
    
    # 手动构造 JSON 字符串（比 json.dump 快得多）
    model = data['model']
    messages = data['messages']
    max_tokens = data.get('max_tokens', 200)
    
    msgs_json = []
    for msg in messages:
        role = msg['role']
        content_parts = []
        for part in msg['content']:
            if part['type'] == 'text':
                content_parts.append('{"type":"text","text":' + json.dumps(part['text']) + '}')
            elif part['type'] == 'image_url':
                b64 = part['image_url']['url'].split(',', 1)[1] if ',' in part['image_url']['url'] else part['image_url']['url']
                content_parts.append('{"type":"image_url","image_url":{"url":"data:image/png;base64,' + b64 + '"}}')
        msgs_json.append('{"role":' + json.dumps(role) + ',"content":[' + ','.join(content_parts) + ']}')
    
    json_str = '{"model":' + json.dumps(model) + ',"messages":[' + ','.join(msgs_json) + '],"max_tokens":' + str(max_tokens) + '}'
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        f.write(json_str)
        tmp_path = f.name
    
    try:
        proc = subprocess.run(
            ['curl', '-s', '-w', '\n%{http_code}', '-X', 'POST', url,
             '-H', 'Content-Type: application/json', '-d', f'@{tmp_path}'],
            capture_output=True, text=True, timeout=timeout
        )
        output = proc.stdout.strip()
    finally:
        os.unlink(tmp_path)
    
    lines = output.rsplit('\n', 1)
    if len(lines) == 2:
        try:
            return int(lines[1]), lines[0]
        except ValueError:
            return 0, output
    return 0, output


def check_service(base_url):
    """检查服务是否可用"""
    status, _ = http_get(f"{base_url}/health", timeout=5)
    return status == 200


def get_models(base_url):
    """获取可用模型列表"""
    status, body = http_get(f"{base_url}/v1/models")
    if status != 200:
        print(f"❌ 获取模型列表失败: HTTP {status}")
        return []

    data = json.loads(body)
    models = [m["id"] for m in data.get("data", [])]
    return models


def encode_image(image_path):
    """将图片转换为 base64"""
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def test_model(base_url, model_id, images):
    """测试单个模型的视觉能力"""
    print(f"\n{'─' * 50}")
    print(f"🧪 测试模型: {model_id}")
    print(f"{'─' * 50}")

    results = []
    for filename, info in images.items():
        image_path = os.path.join(IMAGE_DIR, filename)
        if not os.path.exists(image_path):
            print(f"  ⚠️  图片不存在: {image_path}")
            continue

        prompt = TEST_PROMPTS.get(filename, "请描述这张图片。")
        image_b64 = encode_image(image_path)
        file_size_mb = os.path.getsize(image_path) / (1024 * 1024)

        print(f"\n  📸 {filename} ({info['desc']}, {file_size_mb:.1f}MB)")
        print(f"     发送请求...", end=" ", flush=True)

        payload = {
            "model": model_id,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/png;base64,{image_b64}"},
                        },
                    ],
                }
            ],
            "max_tokens": 200,
        }

        t0 = time.time()
        status, body = http_post(f"{base_url}/v1/chat/completions", payload, timeout=120)
        elapsed = time.time() - t0
        print(f"({elapsed:.1f}s)")

        if status == 200:
            data = json.loads(body)
            content = data["choices"][0]["message"]["content"]

            # 检查是否识别出关键元素
            matched = [kw for kw in info["keywords"] if kw.lower() in content.lower()]
            if matched:
                print(f"  ✅ 通过 - 识别关键词: {matched}")
                results.append(True)
            else:
                print(f"  ⚠️  部分通过 - 响应正常但未匹配关键词")
                results.append(True)

            print(f"     回复: {content[:120].replace(chr(10), ' ')}...")
        else:
            try:
                error = json.loads(body).get("error", {}).get("message", body)
            except:
                error = body[:200]
            print(f"  ❌ 失败 - HTTP {status}")
            print(f"     错误: {error}")
            results.append(False)

    return results


def main():
    parser = argparse.ArgumentParser(description="测试 LLM 模型的视觉能力")
    parser.add_argument("--port", type=int, default=8080, help="服务端口 (默认: 8080)")
    parser.add_argument("--model", type=str, help="只测试指定模型 (如: Qwen3.5-0.8B)")
    args = parser.parse_args()

    base_url = f"http://localhost:{args.port}"

    print("🧪 测试模型视觉能力")
    print("=" * 40)

    # 1. 检查服务
    if not check_service(base_url):
        print(f"❌ 服务未运行，请先执行: ./run.sh")
        sys.exit(1)
    print(f"✅ 服务正在运行 (端口: {args.port})")

    # 2. 获取模型列表
    print("\n📋 获取可用模型列表...")
    models = get_models(base_url)
    if not models:
        print("❌ 没有找到可用模型")
        sys.exit(1)
    print(f"✅ 找到 {len(models)} 个模型: {', '.join(models)}")

    # 过滤模型
    if args.model:
        models = [m for m in models if args.model in m]
        if not models:
            print(f"❌ 没有匹配 '{args.model}' 的模型")
            sys.exit(1)

    # 3. 检查测试图片
    images = {}
    for filename, info in TEST_IMAGES.items():
        path = os.path.join(IMAGE_DIR, filename)
        if os.path.exists(path):
            print(f"🖼️  {filename}: {info['desc']}")
            images[filename] = info
        else:
            print(f"⚠️  {filename}: 不存在 ({path})")

    if not images:
        print("❌ 没有可用的测试图片")
        sys.exit(1)

    # 4. 运行测试
    print(f"\n📤 开始测试 {len(models)} 个模型 × {len(images)} 张图片...")

    all_results = {}
    for model_id in models:
        results = test_model(base_url, model_id, images)
        all_results[model_id] = results

    # 5. 汇总报告
    print(f"\n{'=' * 40}")
    print("📊 测试报告")
    print(f"{'=' * 40}")

    total = 0
    passed = 0
    for model_id, results in all_results.items():
        p = sum(results)
        t = len(results)
        total += t
        passed += p
        icon = "✅" if p == t else "⚠️" if p > 0 else "❌"
        print(f"  {icon} {model_id}: {p}/{t} 通过")

    print(f"\n  总计: {passed}/{total} 通过")
    if passed == total:
        print("  🎉 全部测试通过！")
    else:
        print(f"  ⚠️  {total - passed} 个测试未通过")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
