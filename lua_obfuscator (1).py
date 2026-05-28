#!/usr/bin/env python3
"""
Simple Lua Obfuscator for MoonLoader/LuaJIT
- XOR encryption (no external deps)
- String encoding
- Variable obfuscation
"""

import base64
import random
import string
import argparse
import os
import re

def random_name(length=16):
    """Generate random Lua variable name"""
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

def xor_encrypt(data: bytes, key: bytes) -> bytes:
    """XOR encrypt data with key"""
    result = bytearray(len(data))
    for i, byte in enumerate(data):
        result[i] = byte ^ key[i % len(key)]
    return bytes(result)

def encode_string(s: str) -> str:
    """Encode string to hex escape sequences"""
    result = []
    for char in s:
        result.append(f"\\{ord(char):03d}")
    return ''.join(result)

def obfuscate_lua(source: str, key: str) -> str:
    """Obfuscate Lua source code"""
    
    # Layer 1: XOR encrypt the source
    source_bytes = source.encode('utf-8')
    key_bytes = key.encode('utf-8')
    encrypted = xor_encrypt(source_bytes, key_bytes)
    
    # Layer 2: Base64 encode
    b64 = base64.b64encode(encrypted).decode('ascii')
    
    # Layer 3: Split into chunks and encode as hex
    chunk_size = 64
    chunks = [b64[i:i+chunk_size] for i in range(0, len(b64), chunk_size)]
    
    # Generate obfuscated variable names
    var_data = random_name()
    var_key = random_name()
    var_result = random_name()
    var_func = random_name()
    var_loader = random_name()
    
    # Build the obfuscated script
    # Use a simple XOR implementation that works in pure Lua 5.1
    lua_code = f'''-- Obfuscated with Lua Obfuscator v5.0
-- Encrypted: {len(source_bytes)} bytes

local {var_data} = table.concat({{'''
    
    # Add encrypted data as string chunks
    for i, chunk in enumerate(chunks):
        sep = "," if i < len(chunks) - 1 else ""
        lua_code += f'\n  "{chunk}"{sep}'
    
    lua_code += f'''
}})

local {var_key} = "{key}"

-- XOR decrypt function (pure Lua 5.1, no bit library needed)
local function {var_func}(data, key)
    local result = {{}}
    local keyLen = #key
    for i = 1, #data do
        local c = string.byte(data, i)
        local k = string.byte(key, (i - 1) % keyLen + 1)
        -- XOR without bit library
        local xored = 0
        local bit = 128
        while bit > 0 do
            local cBit = (c >= bit) and 1 or 0
            local kBit = (k >= bit) and 1 or 0
            if cBit ~= kBit then
                xored = xored + bit
            end
            if c >= bit then c = c - bit end
            if k >= bit then k = k - bit end
            bit = math.floor(bit / 2)
        end
        table.insert(result, string.char(xored))
    end
    return table.concat(result)
end

-- Base64 decode function (pure Lua)
local function base64_decode(data)
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {{}}
    local t = {{}}
    local c = 1
    
    for char in string.gmatch(b, ".") do
        t[char] = c - 1
        c = c + 1
    end
    
    data = string.gsub(data, "[^" .. b .. "=]", "")
    
    for i = 1, #data, 4 do
        local n = 0
        local padding = 0
        
        for j = 0, 3 do
            local char = string.sub(data, i + j, i + j)
            if char == "=" then
                padding = padding + 1
                n = n * 64
            else
                n = n * 64 + (t[char] or 0)
            end
        end
        
        for j = 1, 3 - padding do
            local byte = math.floor(n / 256 ^ (3 - j)) % 256
            table.insert(result, string.char(byte))
        end
    end
    
    return table.concat(result)
end

-- Decrypt and execute
local {var_loader} = loadstring or load
if {var_loader} then
    local decoded = base64_decode({var_data})
    local decrypted = {var_func}(decoded, {var_key})
    local success, {var_result} = pcall({var_loader}, decrypted)
    if success and {var_result} then
        {var_result}()
    else
        print("[Obfuscated Script] Failed to load")
    end
end
'''
    
    return lua_code

def main():
    parser = argparse.ArgumentParser(description='Lua Obfuscator for MoonLoader')
    parser.add_argument('input', help='Input Lua file')
    parser.add_argument('-o', '--output', help='Output file (default: input_obfuscated.lua)')
    parser.add_argument('-k', '--key', help='Encryption key (default: random)')
    
    args = parser.parse_args()
    
    input_file = args.input
    output_file = args.output or input_file.replace('.lua', '_obfuscated.lua')
    key = args.key or ''.join(random.choice(string.ascii_letters + string.digits + '!@#$%^&*') for _ in range(32))
    
    # Read source
    with open(input_file, 'r', encoding='utf-8', errors='ignore') as f:
        source = f.read()
    
    print(f"\n🔒 Lua Obfuscator v5.0 (Pure Lua 5.1)")
    print("=" * 50)
    print(f"📁 Input: {input_file}")
    print(f"📊 Size: {len(source)} bytes")
    print(f"🔑 Key: {key[:16]}...")
    
    # Obfuscate
    print("🔐 Encrypting...")
    obfuscated = obfuscate_lua(source, key)
    
    # Save
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(obfuscated)
    
    # Save key
    key_file = output_file + '.key'
    with open(key_file, 'w') as f:
        f.write(key)
    
    print(f"\n✅ Done: {output_file}")
    print(f"📊 Size: {os.path.getsize(output_file)} bytes")
    print(f"🔑 Key: {key_file}")

if __name__ == '__main__':
    main()
