#!/bin/bash

# 默认变量
TASK_NAME=""
AUTHOR=""
BASE_URL="https://api.day.app/nxJQRPyqBgXrZMik6N5Fv6"

# 参数解析
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --task-name) TASK_NAME="$2"; shift ;;
        --author) AUTHOR="$2"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 检查参数是否缺失
if [[ -z "$TASK_NAME" || -z "$AUTHOR" ]]; then
    echo "使用错误！示例: $0 --task-name 接口调试 --author 张三"
    exit 1
fi

# 对中文和特殊字符进行 URL 编码（防止 curl 执行报错）
# 使用 jq 或 python 进行编码，这里推荐最通用的 python 方式
ENCODED_TASK=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TASK_NAME'))")
ENCODED_AUTHOR=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$AUTHOR'))")

# 拼接最终的 URL
# 注意：Bark 的 URL 格式为 /推送标题/推送内容
FULL_URL="${BASE_URL}/${ENCODED_TASK}代码编写任务已完成/From%20${ENCODED_AUTHOR}?call=1"

# 执行 curl
echo "正在发送通知..."
curl -s "$FULL_URL"

echo -e "\n任务已处理。"
