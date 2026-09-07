# FIFO UVM Verification Project

这是一个同步 FIFO 设计与 UVM 验证学习项目。项目按照 Spec、RTL、基础 testbench、UVM 验证平台、覆盖率与回归的顺序逐步完成。

目前已完成 FIFO RTL、设计说明、验证计划、基础 testbench，以及 UVM interface 和 top。最小 UVM test 已通过 VCS 编译和运行，能够取得 interface 并正常结束。下一步开始编写 transaction、sequence、sequencer 和 driver。

基础 testbench 用于观察读写信号和波形；当前 UVM test 只检查测试启动和接口获取，还没有发送读写请求，也没有数据比较和自动判错。

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
│   ├── agents/                   # driver、monitor、sequencer（待实现）
│   ├── env/                      # environment、scoreboard、coverage（待实现）
│   ├── seq/                      # sequences（待实现）
│   ├── sva/                      # assertions（待实现）
│   └── tests/
│       └── fifo_test.sv          # 最小 UVM test：获取接口，等待时钟后结束
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
- [ ] transaction、sequence、sequencer 和 driver
- [ ] monitor 和 agent
- [ ] reference model 和 scoreboard
- [ ] 功能覆盖率
- [ ] SVA
- [ ] 自动回归和补齐未覆盖的测试
- [ ] 故意修改 RTL，确认测试能发现错误

### 2026-09-07 晚间完成内容

- `fifo_if.sv`：定义接口信号；`drv_cb` 在下降沿驱动请求，`mon_cb` 分别采集上升沿前的请求、状态和上升沿后的结果。
- `fifo_tb_top.sv`：产生 10ns 周期时钟，在 20ns 释放复位，连接 interface 和 DUT，通过 `uvm_config_db::set()` 提供接口，调用 `run_test("fifo_test")`。
- `fifo_test.sv`：注册 test，在 `build_phase()` 获取接口，在 `run_phase()` 等待 6 个上升沿，通过 objection 控制测试结束。
- 将早期普通 testbench 的目录由 `scratch/` 改为 `smoke/`。

本次检查依据本地 `compile.log`、`sim.log`：VCS V-2023.12-SP2、UVM-1.1d.Synopsys 完成编译和运行；日志显示 `FIFO interface obtained` 和 `Test completed`，仿真在 55ns 结束，`UVM_WARNING`、`UVM_ERROR`、`UVM_FATAL` 均为 0。这些结果说明最小 UVM 测试已跑通，尚不代表 FIFO 读写功能验证通过。

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

正常运行时应看到 `FIFO interface obtained`、`Test completed`，并检查 UVM 汇总中的错误数量。当前 test 的 virtual interface 固定为 8 位，与 top 的默认 `width=8` 对应；后续做参数测试前，需要统一 test 和 top 的位宽配置。

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

## UVM 验证安排

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

- 用 SystemVerilog queue 保存预期数据，根据队列中的数据个数判断读写是否应该成功；
- scoreboard 逐拍比较读数据、空满标志和错误信号，包括没有成功读取时的输出保持；
- monitor 分别采集上升沿前的输入和上升沿后的结果，单独处理异步复位；
- SVA 检查复位、指针更新、输出保持和错误信号时序；
- 功能覆盖率记录空满状态、四种读写组合、数据个数和指针回卷是否测到；
- 运行定向测试、多个随机 seed 和多种参数配置，再故意修改 RTL 检查测试能否发现错误。

## 下一步

从 `fifo_item` 开始，逐步完成下面的内容：

```text
fifo_item
  -> fifo_sequence
  -> fifo_sequencer
  -> fifo_driver
  -> fifo_monitor
  -> fifo_agent
  -> fifo_scoreboard
  -> fifo_env
  -> 扩展现有 fifo_test
```

先让 `fifo_item` 描述一拍的 `wr_en`、`rd_en` 和 `wr_data`，再通过 sequence、sequencer 和 driver 把请求发送到 DUT。之后加入 monitor 采样和 scoreboard 数据比较，由 env 组织组件，并扩展现有 test 来运行读写测试。

完成基本读写比较后，再按照 vPlan 加入空满、同时读写、复位和回卷等用例，最后实现覆盖率统计、参数测试和自动回归。具体步骤与通过条件见 [验证计划](doc/verification_plan.md)。
