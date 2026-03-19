#!/bin/bash
# 配置信息 - 替换为你的实际信息
if grep -q $'\r' "$0"; then
    echo "检测到脚本包含Windows换行符，自动修复为Unix格式..."
    # 临时文件存储修复后的内容
    TMP_FILE=$(mktemp)
    # 移除CR字符（\r），保留LF
    tr -d '\r' < "$0" > "$TMP_FILE"
    # 覆盖原文件（保留权限）
    cat "$TMP_FILE" > "$0"
    rm -f "$TMP_FILE"
    # 重新执行修复后的脚本（避免当前进程仍用错误格式）
    exec "$0" "$@"
fi

GITHUB_TOKEN="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"
OWNER="Imanity123"
REPO="my-photo-check"
FILE_PATH="data.txt"
BRANCH="main"                  # 改成你实际用的分支（默认main）

# 从环境变量获取 GITHUB_TOKEN，如果未设置则提示并退出
if [ -z "$GITHUB_TOKEN" ]; then
    echo "错误：请先设置环境变量 GITHUB_TOKEN"
    echo "用法：export GITHUB_TOKEN='你的token' && $0 \"要添加的文本\""
    exit 1
fi

# 检查参数
[ $# -eq 0 ] && { echo "用法: $0 \"要添加的文本\""; exit 1; }

NEW_CONTENT="$1 "

# ──────────────────────────────────────────────
# 获取文件元数据（含 content base64 和 sha）
# ──────────────────────────────────────────────
API_URL="https://api.github.com/repos/$OWNER/$REPO/contents/$FILE_PATH"
[ -n "$BRANCH" ] && API_URL="$API_URL?ref=$BRANCH"

FILE_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$API_URL")

# ──────────────────────────────────────────────
# 判断文件是否存在 + 提取 content 和 sha（robust方式）
# ──────────────────────────────────────────────
if echo "$FILE_INFO" | grep -q '"message": *"Not Found"'; then
    EXISTING_CONTENT=""
    SHA=""
else
    # 去掉所有换行和多余空白，让 content 变成单行
    SINGLE_LINE=$(echo "$FILE_INFO" | tr -d '\r\n' | sed 's/ *//g')

    # 提取 base64 部分（"content":"....",）
    B64_PART=$(echo "$SINGLE_LINE" | \
        sed -n 's/.*"content":"\([^"]*\)".*/\1/p')

    if [ -n "$B64_PART" ]; then
        # 解码，失败时当成空（防止 base64: invalid input 炸掉）
        EXISTING_CONTENT=$(echo "$B64_PART" | base64 -d 2>/dev/null || echo "")
    else
        EXISTING_CONTENT=""
    fi

    # 提取 sha
    SHA=$(echo "$SINGLE_LINE" | \
        sed -n 's/.*"sha":"\([^"]*\)".*/\1/p')
fi

# ──────────────────────────────────────────────
# 拼接 & 重新 base64
# ──────────────────────────────────────────────
FINAL_CONTENT="$EXISTING_CONTENT$NEW_CONTENT"
ENCODED_CONTENT=$(echo -n "$FINAL_CONTENT" | base64)

# 去掉可能的换行（有些 base64 实现会加）
ENCODED_CONTENT="${ENCODED_CONTENT//$'\n'/}"

# ──────────────────────────────────────────────
# 准备 payload
# ──────────────────────────────────────────────
if [ -n "$SHA" ]; then
    # 更新已有文件，必须带 sha
    PAYLOAD="{\"message\":\"Append text\",\"content\":\"$ENCODED_CONTENT\",\"sha\":\"$SHA\""
    [ -n "$BRANCH" ] && PAYLOAD="$PAYLOAD,\"branch\":\"$BRANCH\""
    PAYLOAD="$PAYLOAD}"
else
    # 创建新文件
    PAYLOAD="{\"message\":\"Create/append to data.txt\",\"content\":\"$ENCODED_CONTENT\""
    [ -n "$BRANCH" ] && PAYLOAD="$PAYLOAD,\"branch\":\"$BRANCH\""
    PAYLOAD="$PAYLOAD}"
fi

RESPONSE=$(curl -s -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$PAYLOAD" \
    "https://api.github.com/repos/$OWNER/$REPO/contents/$FILE_PATH")

echo "FINISH"
