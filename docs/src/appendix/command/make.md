# Make

使用**缩进**而非空格。

## 规则

```makefile
target ... : prerequisites ...
    recipe
    ...
```

- target: 文件或标签（伪指令）
- prerequisites: 生成 target 所需的前置文件或 target
- recipe: 生成 target 的一系列命令

## 伪指令

有时候 target 并不需要生成一个文件，而只是单纯地执行命令。

```makefile
.PHONY: clean
clean:
    rm -rf build
```

## 变量

### 自动化变量

#### $@

表示规则中的目标文件集。

#### $%

#### $<

依赖目标中的**第一个**目标名字。

#### $^

所有依赖目标的集合，以空格分隔。若有重复依赖，则只保留一个。

#### $+

与`$^`相似，但不去除重复依赖。

#### $(@D)

表示`$@`的目录部分，不以斜杠结尾。若`$@`没有斜杠则为`.`，表示当前目录。

```make
build/myapp: main.o utils.o
    # mkdir -p build
    mkdir -p $(@D)
    gcc $^ -o $@
```

## 函数

Make 提供了一些函数来处理变量。函数调用后，返回值可以用作变量来使用。

```make
$(<function> <argument>[, ...])
${<function> <argument>[, ...]}

```

### 字符串处理

#### subst 字符串替换

```make
$(subst <from>,<to>,<text>)
```

把字符串`text`中的`from`替换成`to`。返回被替换过的字符串。

#### patsubst 模式字符串替换

```make
$(patsubst <pattern>,<replacement>,<text>)
```

查找`text`中的单词（以空格、Tab、换行等空白符分隔）是否符合模式`pattern`，如果匹配则以`replacement`替换。

```make
$(patsubst %.c, %.o, x.c.c bar.c)
# x.c.o bar.o
```

## Tips

### 不打印执行的命令

Make 执行命令前会先打印要执行的命令，如果不想 Make 打印命令可以在命令前添加 `@`。

打印要执行的命令：

```makefile
.PHONY: test
test:
    echo Hello

# echo Hello
# Hello
```

不打印要执行的命令：

```makefile
.PHONY: test
test:
    @echo Hello

# Hello
```

## 参考资料

1. [跟我一起写 Makefile](https://seisman.github.io/how-to-write-makefile/index.html)
