#!/usr/bin/env python3
"""
PubMed MCP Server 快速测试客户端
用于通过 stdio 管道向 Docker 容器发送标准 JSON-RPC 请求并打印返回结果
"""
import subprocess
import json
import sys

def test_mcp_server():
    print("正在连接 PubMed MCP 容器并测试握手与工具列表...")
    
    # 启动 docker 进程
    cmd = ["docker", "run", "-i", "--rm", "--env-file", ".env", "pubmed-mcp:latest"]
    
    try:
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
    except Exception as e:
        print(f"启动 Docker 容器失败: {e}")
        sys.exit(1)

    # 1. 发送 initialize 请求
    init_req = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "test-client", "version": "1.0.0"}
        }
    }
    
    # 2. 发送 tools/list 请求获取工具列表
    tools_req = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    }

    input_payload = json.dumps(init_req) + "\n" + json.dumps(tools_req) + "\n"
    
    try:
        stdout, stderr = proc.communicate(input=input_payload, timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        print("测试超时！")
        sys.exit(1)

    print("\n=== 服务端返回响应 (STDOUT) ===")
    for line in stdout.strip().split("\n"):
        if not line:
            continue
        try:
            parsed = json.loads(line)
            print(json.dumps(parsed, indent=2, ensure_ascii=False))
        except Exception:
            print(line)

    if stderr.strip():
        print("\n=== 日志输出 (STDERR) ===")
        print(stderr.strip())

if __name__ == "__main__":
    test_mcp_server()
