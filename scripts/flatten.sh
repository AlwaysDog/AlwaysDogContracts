#!/bin/bash

# 创建 flattened 目录
mkdir -p flattened

# 遍历 contracts 目录下的所有 .sol 文件
find contracts -name "*.sol" | while read file; do
    # 跳过 mocks 目录下的文件
    if [[ $file != *"mocks"* ]]; then
        echo "Flattening $file..."
        
        # 获取相对路径和文件名
        relative_path=${file#contracts/}
        target_dir="flattened/$(dirname "$relative_path")"
        
        # 创建目标目录
        mkdir -p "$target_dir"
        
        # 创建临时文件
        temp_file=$(mktemp)
        
        # 扁平化合约到临时文件
        npx hardhat flatten "$file" > "$temp_file" 2>/dev/null
        
        # 添加必要的 pragma 和 license 到最终文件
        {
            echo "// SPDX-License-Identifier: MIT"
            echo "pragma solidity ^0.8.0;"
            echo "pragma abicoder v2;"
            echo ""
            # 过滤掉所有的 license 和 pragma 行，保留其他所有内容
            grep -v "// SPDX-License-Identifier:" "$temp_file" | grep -v "pragma " 
        } > "flattened/$relative_path"
        
        # 删除临时文件
        rm "$temp_file"
        
        echo "Successfully flattened $relative_path"
    fi
done

echo "Flattening complete!" 