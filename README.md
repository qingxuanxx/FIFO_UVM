# FIFO UVM Verification Project

这是一个同步 FIFO 设计与 UVM 验证学习项目。项目按照 Spec、RTL、基础 testbench、UVM 验证平台、覆盖率与回归的顺序逐步完成。

目前已完成 FIFO RTL、设计说明、验证计划、基础 testbench，以及 UVM interface、transaction、sequence、sequencer 和 driver。UVM test 已能产生一笔随机请求并通过 driver 驱动 DUT，下一步实现 monitor。

基础 testbench 用于观察读写信号和波形；当前 UVM test 尚未加入 monitor、scoreboard 和自动数据比较。

- [设计说明（Spec）](doc/fifo_spec.md)：参数、接口、复位、读写操作和错误信号。
- [验证计划（vPlan）](doc/verification_plan.md)：测试步骤、检查方法、覆盖率和回归通过条件。

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
- `width` 必须不小于 1，`depth` 必须不小于 2，并且是 2 的幂；
- 读数据在成功读取的上升沿后更新，不会在写入后自动显示；
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
| `rd_data` | output | `width` | 最近一次成功读取的数据，复位时清零 |
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

除复位外，`rd_data` 只在成功读取的上升沿后更新。没有读请求或空读时，`rd_data` 保持原值。

错误信号在每个上升沿重新计算：本次满写则 `wr_error=1`，本次空读则 `rd_error=1`；下一拍没有对应错误时清零。

## 目录结构

```text
FIFO_UVM/
├── doc/
│   ├── fifo_spec.md              # FIFO 设计说明
│   └── verification_plan.md      # FIFO 验证计划
├── rtl/
│   └── fifo.v                    # FIFO RTL
├── smoke/
│   └── fifo_tb.sv                # 非 UVM smoke testbench
├── tb/
│   ├── fifo_if.sv                # 接口信号、driver 和 monitor 的 clocking block
│   ├── fifo_tb_top.sv            # 时钟、复位、DUT 连接和 UVM 启动
│   ├── agents/                   # item、sequencer、driver 和 agent
│   ├── env/                      # environment、scoreboard、coverage（待实现）
│   ├── seq/                      # FIFO sequence
│   ├── sva/                      # assertions（待实现）
│   └── tests/
│       └── fifo_test.sv          # 创建 agent 并启动 sequence
└── sim/
    ├── Makefile                  # 编译和仿真入口（待完成）
    ├── filelist.f                # UVM 文件列表（待完成）
    └── regress.py                # 回归脚本（待完成）
```

## 当前进度

- [x] FIFO RTL 第一版
- [x] FIFO 设计说明 Spec
- [x] 验证计划 vPlan
- [x] 基础 smoke testbench
- [x] VCS 编译和仿真
- [x] Verdi 波形查看
- [x] UVM interface 和 top
- [x] transaction（`fifo_item`）
- [x] sequence、sequencer 和 driver
- [ ] monitor 和完善 agent
- [ ] reference model 和 scoreboard
- [ ] 功能覆盖率
- [ ] SVA
- [ ] 自动回归和补齐未覆盖的测试
- [ ] 故意修改 RTL，确认测试能发现错误

## 编译和运行 UVM 测试

安装并配置好 VCS 后，在项目根目录执行：

```bash
vcs -full64 -sverilog -ntb_opts uvm \
    -timescale=1ns/1ps \
    +incdir+tb \
    -kdb -debug_access+all \
    rtl/fifo.v \
    tb/fifo_if.sv \
    tb/fifo_tb_top.sv \
    -top fifo_tb_top \
    -o simv_if \
    -l compile.log
```

编译成功后运行：

```bash
./simv_if -l sim.log
```

- `-ntb_opts uvm`：加载 VCS 提供的 UVM 库。
- `-timescale=1ns/1ps`：为未显式声明时间尺度的设计单元提供默认值。
- `+incdir+tb`：指定 include 文件的查找目录。top 已包含 `tests/fifo_test.sv`，不需要在命令中再次列出它。
- `-top fifo_tb_top`：使用 UVM 仿真顶层。
- `-l`：保存编译或仿真日志。

正常运行时应看到 `FIFO interface obtained`、`FIFO_DRIVER`、`Sequence completed` 和 `Test completed`，并检查 UVM 汇总中的错误数量。当前 test 的 virtual interface 固定为 8 位，与 top 的默认 `width=8` 对应；后续做参数测试前，需要统一 test 和 top 的位宽配置。

## 编译和运行普通 smoke 测试

安装并配置好 VCS 后，在项目根目录执行。当前 `sim/Makefile` 和回归脚本还未实现，先直接编译基础 testbench：

```bash
vcs -full64 -sverilog -kdb -debug_access+all \
    rtl/fifo.v \
    smoke/fifo_tb.sv \
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

以下命令查看普通 smoke 测试产生的 `fifo_tb.vcd`。当前 UVM top 尚未添加波形输出代码。如果 Verdi 运行在 Linux、界面显示到 Windows，需要先在 Windows 启动 XLaunch/VcXsrv，然后执行：

```bash
verdi -sv \
    rtl/fifo.v \
    smoke/fifo_tb.sv \
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

> 最后更新：2026-09-12
