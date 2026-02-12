# 开发环境

## 构建工具

```language
$ make --version
GNU Make 4.4.1
Built for x86_64-pc-linux-gnu
Copyright (C) 1988-2023 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
```

## 编译工具链

```language
$ gcc --version
gcc (GCC) 15.2.1 20260103
Copyright (C) 2025 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

## IDE

```language
$ nvim --version
NVIM v0.11.5
Build type: RelWithDebInfo
LuaJIT 2.1.1767980792
Run "nvim -V1 -v" for more info
```

Nvim 配置：https://github.com/TPCAD/neovim-configuration

```language
$ bear --version
bear 4.0.2
```

使用 `bear` 生成 `compile_commands.json`：

```bash
bear -- make build
```

## 模拟器

### Bochs

```language
$ bochs -h
========================================================================
                        Bochs x86 Emulator 2.8
             Built from GitHub snapshot on March 10, 2024
                Timestamp: Sun Mar 10 08:00:00 CET 2024
========================================================================
```

### QEMU

```language
$ qemu-system-i386 --version
QEMU emulator version 10.2.0
Copyright (c) 2003-2025 Fabrice Bellard and the QEMU Project developers
```

## 调试

编译时使用`gcc -g`或`as -g`生成调试信息。

### VSCode

`launch.json`。

```json
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit:
    // https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        // debug kernel with bochs and qemu via gdb
        {
            "name": "linuxmodi - build and debug kernel file",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/system.o",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${fileDirname}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "miDebuggerServerAddress": "localhost:1234",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            "miDebuggerPath": "/usr/bin/gdb"
        }
    ]
}
```

### QEMU

`-s`选项是`-gdb tcp::1234`的简写，开启后以 GDB 启动镜像。`-S`选项可在启动时冻结 CPU 方便在 IDE 中监听 GDB。
