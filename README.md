# FIFO UVM Verification Project

这是一个同步 FIFO 设计与 UVM 验证学习项目。项目按照 Spec、RTL、基础 testbench、UVM 验证平台、覆盖率与回归的顺序逐步完成。

目前已经完成 FIFO RTL、Spec、vPlan 和基础 smoke test。RTL 已使用 VCS 编译并运行成功，也可以通过 Verdi 查看波形。下一阶段开始搭建 UVM 验证平台。

## DUT 设计说明

DUT 模块名为 `fifo`，默认参数为：

```text
width = 8
depth = 16
```

主要特点：

- 单时钟同步读写；
- 高电平有效的异步复位；
- 使用带回卷位的扩展读写指针判断空满；
- FIFO 可以使用完整的 `depth` 个存储位置；
- `depth` 必须不小于 2，并且是 2 的幂；
- 使用注册型同步读，不是 FWFT；
- 满写和空读会被拒绝；
- 非法操作分别通过 `wr_error` 和 `rd_error` 输出；
- RAM 不复位，复位时清除指针、读数据和错误输出。

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

合法读写条件为：

```systemverilog
wr_valid = wr_en && !full;
rd_valid = rd_en && !empty;
```

读写请求根据时钟上升沿之前的空满状态独立判断：

| FIFO 当前状态 | `wr_en` | `rd_en` | 写操作 | 读操作 |
|---|---:|---:|---|---|
| 非空非满 | 1 | 1 | 成功 | 成功 |
| 空 | 1 | 1 | 成功 | 拒绝 |
| 满 | 1 | 1 | 拒绝 | 成功 |

`rd_data` 只在合法读操作发生后更新。FIFO 非空但 `rd_en=0` 时，`rd_data` 保持原值。

更完整的设计行为见 [FIFO 功能规格](doc/fifo_spec.md)。验证目标和 Feature/Testcase 对应关系见 [FIFO 验证计划](doc/verification_plan.md)。

## 目录结构

```text
FIFO_UVM/
├── doc/
│   ├── fifo_spec.md              # FIFO 功能规格
│   └── verification_plan.md      # FIFO 验证计划
├── rtl/
│   └── fifo.v                    # FIFO RTL
├── scratch/
│   └── fifo_tb.sv                # 非 UVM smoke testbench
├── tb/
│   ├── fifo_if.sv                # FIFO interface（待完成）
│   ├── agents/                   # driver、monitor、sequencer
│   ├── env/                      # environment、scoreboard、coverage
│   ├── seq/                      # sequences
│   ├── sva/                      # assertions
│   └── tests/                    # testcases
└── sim/
    ├── Makefile                  # 编译和仿真入口（待完成）
    ├── filelist.f                # UVM 文件列表（待完成）
    └── regress.py                # 回归脚本（待完成）
```

## 当前进度

- [x] FIFO RTL 第一版
- [x] FIFO 功能规格 Spec
- [x] Verification Plan
- [x] 基础 smoke testbench
- [x] VCS 编译和仿真
- [x] Verdi 波形查看
- [ ] UVM interface 和 top
- [ ] transaction、sequence、sequencer 和 driver
- [ ] monitor 和 agent
- [ ] reference model 和 scoreboard
- [ ] functional coverage
- [ ] SVA
- [ ] 自动回归和覆盖率收敛
- [ ] 故障注入

## 使用 VCS 编译和运行

在项目根目录执行：

```bash
vcs -full64 -sverilog -kdb -debug_access+all \
    rtl/fifo.v \
    scratch/fifo_tb.sv \
    -top fifo_tb \
    -o simv
```

参数说明：

- `-full64`：使用 64 位模式；
- `-sverilog`：按 SystemVerilog 语法编译；
- `-kdb`：生成 Verdi 使用的设计数据库；
- `-debug_access+all`：允许查看 DUT 内部信号；
- `-top fifo_tb`：指定 testbench 顶层模块；
- `-o simv`：生成名为 `simv` 的仿真程序。

运行仿真：

```bash
./simv
```

仿真完成后会生成 `fifo_tb.vcd`。当前 smoke test 包含：

- 异步复位；
- 空状态读取和 `rd_error`；
- 连续写满 FIFO；
- 满状态写入和 `wr_error`；
- 非空非满状态下同时读写；
- 随机读写；
- 最终清空 FIFO。

## 使用 Verdi 查看波形

如果 Verdi 运行在 Linux、界面显示到 Windows，需要先在 Windows 启动 XLaunch/VcXsrv，然后执行：

```bash
verdi -sv \
    rtl/fifo.v \
    scratch/fifo_tb.sv \
    -top fifo_tb \
    -ssf fifo_tb.vcd &
```

建议观察以下信号：

```text
clk rst
wr_en wr_data wr_error
rd_en rd_data rd_error
full empty
dut.wr_ptr dut.rd_ptr
dut.wr_valid dut.rd_valid
```

## UVM 验证策略

验证平台计划使用一个 active FIFO agent，同时驱动读写接口，以正确处理同拍读写：

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

- 使用 SystemVerilog queue 建立与 DUT 实现独立的 reference model；
- scoreboard 检查数据、顺序、模型水位、空满标志和 error；
- SVA 检查复位、非法操作、指针更新和逐拍时序；
- functional coverage 检查空满边界、同时读写、水位和指针回卷；
- 通过多 testcase、多 seed、多参数配置和故障注入完成回归。

## 下一步

按照以下顺序搭建 UVM 平台：

```text
fifo_if
  -> fifo_item
  -> fifo_sequencer
  -> fifo_driver
  -> fifo_monitor
  -> fifo_agent
  -> fifo_scoreboard
  -> fifo_env
  -> fifo_test
  -> fifo_tb_top
```

平台搭建完成后，再根据 vPlan 中的 Feature 编写对应 sequence/testcase，并使用 scoreboard、SVA 和 coverage 自动判断验证结果。
