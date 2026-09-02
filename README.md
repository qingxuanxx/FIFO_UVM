# FIFO UVM Verification Project

这是一个同步 FIFO 的设计与 UVM 验证学习项目。项目从功能规格开始，逐步完成 RTL、裸 testbench、UVM 验证平台、功能覆盖率、SVA 和自动回归。

当前阶段已经完成 FIFO RTL 第一版、功能规格和验证计划，裸 testbench 与 UVM 平台正在搭建中。

## DUT 设计说明

`my_fifo` 是一个单时钟同步 FIFO，默认配置为：

```text
数据宽度 width = 8
FIFO 深度 depth = 16
```

主要特点：

- 单时钟同步读写；
- 高电平有效的异步复位；
- 使用带回卷位的扩展读写指针判断空满；
- FIFO 可使用完整的 `depth` 个存储位置；
- `depth` 必须是不小于 2 的二次幂；
- 使用注册型同步读，不是 FWFT；
- 满写和空读会被拒绝；
- 非法操作通过 `wr_error` 和 `rd_error` 输出；
- RAM 不复位，复位时只清除指针、读数据和错误输出。

## DUT 接口

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `clk` | input | 1 | FIFO 工作时钟 |
| `rst` | input | 1 | 高电平有效的异步复位 |
| `wr_en` | input | 1 | 写使能 |
| `wr_data` | input | `width` | 写入数据 |
| `rd_en` | input | 1 | 读使能 |
| `rd_data` | output | `width` | 注册型读数据输出 |
| `full` | output | 1 | FIFO 满标志 |
| `empty` | output | 1 | FIFO 空标志 |
| `wr_error` | output | 1 | 满状态下发生写请求 |
| `rd_error` | output | 1 | 空状态下发生读请求 |

## 读写行为

合法操作条件为：

```systemverilog
wr_valid = wr_en && !full;
rd_valid = rd_en && !empty;
```

读写请求使用时钟沿之前的空满状态独立判断，因此边界行为如下：

| FIFO 状态 | `wr_en` | `rd_en` | 写操作 | 读操作 |
|---|---:|---:|---|---|
| 非空非满 | 1 | 1 | 成功 | 成功 |
| 空 | 1 | 1 | 成功 | 拒绝 |
| 满 | 1 | 1 | 拒绝 | 成功 |

`rd_data` 只在合法读操作发生后更新。当 FIFO 非空但 `rd_en=0` 时，`rd_data` 保持原值。

## 空满判断

读写指针的位宽为：

```text
addr_width = $clog2(depth)
ptr_width  = addr_width + 1
```

指针低位作为 RAM 地址，最高位用于区分回卷状态：

```systemverilog
empty = (wr_ptr == rd_ptr);

full = (wr_ptr[ptr_width-1] != rd_ptr[ptr_width-1]) &&
       (wr_ptr[ptr_width-2:0] == rd_ptr[ptr_width-2:0]);
```

## 验证策略

验证平台计划使用一个 active FIFO agent，同时驱动读写接口，以便正确处理同拍读写。

```text
fifo_sequence
      |
fifo_sequencer
      |
fifo_driver
      |
   fifo_if  ---------> DUT
      |
fifo_monitor
      |
      +-------------> fifo_scoreboard
      |
      +-------------> fifo_coverage

DUT 内部/接口信号 ---> FIFO SVA
```

主要检查方法：

- 使用 SystemVerilog queue 建立与 DUT 指针实现独立的 reference model；
- scoreboard 检查数据内容、FIFO 顺序、模型水位和空满状态；
- SVA 检查复位、满写、空读、指针更新和 error 时序；
- functional coverage 检查空满边界、同拍读写、水位和指针回卷；
- 通过故障注入确认验证平台能够发现 DUT 错误；
- 使用多 testcase、多 seed 和多参数配置进行回归。

详细内容见：

- [FIFO 功能规格](doc/fifo_spec.md)
- [FIFO 验证计划](doc/verification_plan.md)

## 目录结构

```text
FIFO_UVM/
├── doc/
│   ├── fifo_spec.md              # FIFO 功能规格
│   └── verification_plan.md      # 验证计划
├── rtl/
│   └── my_fifo.v                 # FIFO RTL
├── scratch/
│   └── smoke_tb.sv               # 非 UVM 冒烟 testbench
├── tb/
│   ├── fifo_if.sv                # FIFO interface
│   ├── agents/                   # driver、monitor、sequencer
│   ├── env/                      # environment、scoreboard、coverage
│   ├── seq/                      # sequences
│   ├── sva/                      # assertions
│   └── tests/                    # testcases
└── sim/
    ├── Makefile                  # 编译和仿真入口
    ├── filelist.f                # 文件列表
    └── regress.py                # 回归脚本
```

## 当前进度

- [x] FIFO RTL 第一版
- [x] RTL 语法解析
- [x] FIFO 功能规格
- [x] Verification Plan
- [ ] 裸 testbench 与波形确认
- [ ] UVM interface 和 top
- [ ] sequence、sequencer 和 driver
- [ ] monitor
- [ ] reference model 和 scoreboard
- [ ] functional coverage
- [ ] SVA
- [ ] 自动回归和覆盖率收敛
- [ ] 故障注入

## RTL 语法检查

RTL 使用了 `logic`、`always_ff` 和带类型参数，需要按 SystemVerilog 编译。使用 VCS 可以执行：

```bash
vcs -full64 -sverilog -parse_only rtl/my_fifo.v
```

当前 RTL 已在 VCS 2023.12 下通过语法和语义解析。

## 后续计划

下一步先完成 `scratch/smoke_tb.sv`，通过波形确认以下行为：

1. 异步复位；
2. 单写单读；
3. 连续写满和满写；
4. 连续读空和空读；
5. 普通、空、满状态下的同拍读写；
6. 读写指针多次回卷。

确认 RTL 和 Spec 一致以后，再开始搭建 UVM 平台。
