# 同步 FIFO 验证计划

## 1. 验证目标

待验证的 DUT 是 `fifo`，源文件为 `rtl/fifo.v`，它是一个单时钟同步 FIFO。

默认参数为：

```text
width = 8
depth = 16
```

这个 FIFO 的主要特点是：

- 使用高电平有效的异步复位；
- 使用带回卷位的扩展读写指针；
- `depth` 必须是 2 的幂；
- 使用注册型同步读，不是 FWFT；
- FIFO 满时不能继续写；
- FIFO 空时不能继续读；
- 非法写入通过 `wr_error` 表示；
- 非法读取通过 `rd_error` 表示。

验证的主要目标是确认数据不会丢失、不会重复、不会被错误覆盖，并且空满状态、error 和读数据时序都符合 Spec。

## 2. DUT 接口

| 信号 | 方向 | 作用 |
|---|---|---|
| `clk` | input | FIFO 工作时钟 |
| `rst` | input | 高电平有效的异步复位 |
| `wr_en` | input | 写使能 |
| `wr_data` | input | 写入数据 |
| `rd_en` | input | 读使能 |
| `rd_data` | output | 注册型读数据 |
| `full` | output | FIFO 满标志 |
| `empty` | output | FIFO 空标志 |
| `wr_error` | output | FIFO 满时仍然请求写入 |
| `rd_error` | output | FIFO 空时仍然请求读取 |

## 3. 验证平台结构

因为读写使用同一个时钟，而且需要验证同拍读写，所以验证平台使用一个 FIFO agent，同时驱动 `wr_en`、`wr_data` 和 `rd_en`。

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

平台计划包含：

- `fifo_if`：连接 DUT 和 UVM 平台；
- `fifo_item`：描述每个周期的读写请求；
- `fifo_sequencer`：把 sequence item 发送给 driver；
- `fifo_driver`：驱动 `wr_en`、`wr_data` 和 `rd_en`；
- `fifo_monitor`：采集 DUT 接口上的实际行为；
- `fifo_scoreboard`：使用队列预测 FIFO 数据和状态；
- `fifo_coverage`：统计功能场景是否覆盖；
- SVA：检查空满、指针、error 和逐拍时序；
- tests/sequences：产生定向和随机测试。

## 4. Transaction 设计

### 4.1 激励 transaction

`fifo_item` 至少包含：

```systemverilog
rand logic             wr_en;
rand logic             rd_en;
rand logic [width-1:0] wr_data;
```

后面如果需要加入随机空闲周期，可以再增加 `delay` 字段。

### 4.2 monitor transaction

monitor 发送给 scoreboard 的 transaction 需要包含：

```text
wr_en
rd_en
wr_data
pre_full
pre_empty
rd_data
post_full
post_empty
wr_error
rd_error
rst
```

其中：

- `pre_full/pre_empty` 表示上升沿之前的状态，用来判断本拍操作是否被接受；
- `post_full/post_empty` 表示上升沿更新后的状态；
- `rd_data`、`wr_error` 和 `rd_error` 要采集上升沿非阻塞赋值完成后的值。

monitor 不能只采一次所有信号，否则容易把沿前状态和沿后结果混在一起，导致 scoreboard 差一拍。

## 5. Feature 和 Testcase 对应关系

Feature 表示需要验证的一条具体功能。每个 P0 Feature 都必须能够自动判断 PASS 或 FAIL。

| ID | Feature | Testcase | 检查方式 | 优先级 |
|---|---|---|---|---|
| F01 | 异步复位后指针和输出正确 | `tc_reset` | monitor + SVA | P0 |
| F02 | 复位期间不接受读写 | `tc_reset_request` | scoreboard + SVA | P0 |
| F03 | 单个数据写入和读出正确 | `tc_single_wr_rd` | scoreboard | P0 |
| F04 | 连续写入和读取顺序正确 | `tc_burst` | scoreboard | P0 |
| F05 | `rd_data` 只在合法读以后更新 | `tc_read_timing` | scoreboard + SVA | P0 |
| F06 | FIFO 可以保存完整的 `depth` 个数据 | `tc_fill_to_full` | scoreboard | P0 |
| F07 | 写入第 `depth` 个数据后 `full=1` | `tc_fill_to_full` | scoreboard + SVA | P0 |
| F08 | FIFO 满时继续写不会覆盖旧数据 | `tc_overflow` | scoreboard + SVA | P0 |
| F09 | 满写时 `wr_error=1` | `tc_overflow` | scoreboard + SVA | P0 |
| F10 | 读出最后一个数据后 `empty=1` | `tc_drain_to_empty` | scoreboard + SVA | P0 |
| F11 | FIFO 空时继续读不会移动读指针 | `tc_underflow` | scoreboard + SVA | P0 |
| F12 | 空读时 `rd_data` 保持且 `rd_error=1` | `tc_underflow` | scoreboard + SVA | P0 |
| F13 | 普通状态同拍读写都成功 | `tc_simultaneous` | scoreboard | P0 |
| F14 | 空状态同拍读写只有写成功 | `tc_empty_wr_rd` | scoreboard + coverage | P0 |
| F15 | 满状态同拍读写只有读成功 | `tc_full_wr_rd` | scoreboard + coverage | P0 |
| F16 | 读写指针回卷以后数据顺序正确 | `tc_wraparound` | scoreboard + coverage | P0 |
| F17 | 随机长时间读写数据正确 | `tc_random` | scoreboard | P0 |
| F18 | 运行中复位会清除逻辑有效数据 | `tc_mid_reset` | scoreboard + SVA | P1 |
| F19 | 连续满写时 error 可以连续为 1 | `tc_error_burst` | scoreboard + SVA | P1 |
| F20 | 连续空读时 error 可以连续为 1 | `tc_error_burst` | scoreboard + SVA | P1 |
| F21 | `depth=2/4/8/16/32` 配置可运行 | 参数回归 | compile + scoreboard | P1 |
| F22 | 非 2 的幂 depth 会被 `$fatal` 拒绝 | 非法参数测试 | 仿真退出结果 | P1 |
| F23 | 不同数据位宽可以正常运行 | 参数回归 | scoreboard | P1 |

## 6. Testcase 计划

### 6.1 `tc_reset`

测试内容：

1. 在没有时钟上升沿的位置拉高 `rst`；
2. 检查异步复位是否立即生效；
3. 检查 `empty=1`、`full=0`；
4. 检查 `rd_data=0`、`wr_error=0`、`rd_error=0`；
5. 在时钟下降沿释放复位；
6. 检查下一个上升沿以后能够正常读写。

### 6.2 `tc_single_wr_rd`

先写入一个固定数据，例如 `8'hA5`，再发出一个读请求。

检查：

- 写入后 FIFO 不再为空；
- `rd_data` 在合法读上升沿之后更新为 `8'hA5`；
- 读完后 FIFO 再次为空；
- 两个 error 都没有错误拉高。

### 6.3 `tc_burst`

连续写入一组不同的数据，再连续读出。

例如：

```text
写入：11, 22, 33, 44, 55
期望读出：11, 22, 33, 44, 55
```

检查 FIFO 顺序和每拍连续读写能力。

### 6.4 `tc_fill_to_full`

连续写入恰好 `depth` 个数据。

检查：

- 前 `depth` 次写都成功；
- 第 `depth` 次写入后 `full=1`；
- FIFO 的有效容量不是 `depth-1`。

### 6.5 `tc_overflow`

先把 FIFO 写满，再继续写至少 3 个不同的数据。

检查：

- 这些写请求全部被拒绝；
- 写指针保持；
- 原来 FIFO 中的数据没有被覆盖；
- 每个拒绝周期 `wr_error=1`；
- 排空 FIFO 后读出的仍然是最初成功写入的数据。

### 6.6 `tc_drain_to_empty`

先写入若干数据，再全部读出。

检查最后一个数据读出以后 `empty=1`，并确认所有数据只读出一次。

### 6.7 `tc_underflow`

FIFO 为空时连续读取至少 3 个周期。

检查：

- 读指针保持；
- `rd_data` 保持；
- 每个拒绝周期 `rd_error=1`。

### 6.8 `tc_simultaneous`

先把 FIFO 水位调整到非空非满，再连续进行同拍读写。

检查：

- 每拍读写都成功；
- 读出的是本拍之前的队首；
- 新数据进入队尾；
- FIFO 中数据数量保持不变。

### 6.9 `tc_empty_wr_rd`

FIFO 为空时，同时拉高 `wr_en` 和 `rd_en`。

检查：

- 写入成功；
- 读取失败；
- `rd_error=1`；
- 新数据没有在同一拍直接输出；
- 写入后 `empty=0`。

### 6.10 `tc_full_wr_rd`

FIFO 满时，同时拉高 `wr_en` 和 `rd_en`。

检查：

- 读取成功；
- 写入失败；
- `wr_error=1`；
- 被拒绝的数据没有进入 FIFO；
- 读取后 `full=0`。

### 6.11 `tc_wraparound`

交替进行多组读写，让读写指针至少分别回卷 3 次。写入数据使用递增值或带编号的数据，方便检查顺序。

### 6.12 `tc_random`

随机运行至少 1000 个周期，让下面四种组合都能出现：

```text
wr_en=0, rd_en=0
wr_en=1, rd_en=0
wr_en=0, rd_en=1
wr_en=1, rd_en=1
```

随机结束后停止写入，继续读取直到 FIFO 为空。scoreboard 中不应该留下未读数据。

### 6.13 `tc_mid_reset`

FIFO 中已经有数据时拉高 `rst`。

检查：

- FIFO 立即进入空状态；
- 复位前没有读出的数据作废；
- 复位释放后可以重新正常读写。

## 7. Reference Model

参考模型使用 SystemVerilog queue：

```systemverilog
logic [width-1:0] expected_q[$];
```

参考模型和 DUT 使用不同方法：DUT 使用扩展指针，参考模型使用 queue，这样不会把 DUT 的同一个错误复制到模型里。

每个时钟周期先根据 monitor 采集到的沿前状态判断：

```text
write_accept = wr_en && !pre_full
read_accept  = rd_en && !pre_empty
```

模型处理规则：

1. 如果 `read_accept=1`，从 `expected_q` 队首取出期望数据；
2. 如果 `write_accept=1`，把 `wr_data` 放到 `expected_q` 队尾；
3. 合法读时比较 `rd_data` 和期望数据；
4. 根据 queue 是否为空或达到 `depth`，比较 DUT 沿后的 `empty/full`；
5. 根据拒绝条件比较 `wr_error/rd_error`。

普通状态同拍读写时，模型先 pop 再 push，读出的应该是本拍之前已经存在的旧队首。

参考模型必须连接 monitor，不能连接 driver。driver 表示“准备发送什么”，monitor 才表示 DUT 接口上实际发生了什么。

## 8. Scoreboard 检查内容

scoreboard 需要自动检查：

- 成功读出的数据是否正确；
- 数据顺序是否正确；
- 被拒绝的写数据是否没有进入模型；
- 空读是否没有消耗数据；
- `post_empty` 是否等于 `expected_q.size()==0`；
- `post_full` 是否等于 `expected_q.size()==depth`；
- `wr_error` 是否等于沿前 `wr_en && full`；
- `rd_error` 是否等于沿前 `rd_en && empty`；
- 复位时是否清空参考模型；
- 测试结束时是否还有未读数据；
- 是否至少发生过一次有效检查。

scoreboard 还可以统计：

```text
成功写次数
成功读次数
数据匹配次数
数据不匹配次数
满写次数
空读次数
最大模型水位
```

## 9. SVA 检查计划

### 9.1 复位

- 复位后 `wr_ptr=0`、`rd_ptr=0`；
- 复位后 `empty=1`、`full=0`；
- 复位后 `rd_data=0`；
- 复位后两个 error 为 0。

异步复位是否立即生效，可以在 testbench 中检测 `posedge rst` 后的状态。时钟相关行为再使用以 `clk` 为采样时钟的 SVA。

### 9.2 空满状态

- `full` 和 `empty` 不能同时为 1；
- 读写指针相同时 `empty=1`；
- 地址部分相同且最高位不同时 `full=1`。

### 9.3 写操作

- `wr_en && full` 时，下一拍写指针保持；
- `wr_en && !full` 时，下一拍写指针加 1；
- 满写时 `wr_error=1`；
- 没有满写请求时 `wr_error=0`。

### 9.4 读操作

- `rd_en && empty` 时，下一拍读指针和 `rd_data` 保持；
- `rd_en && !empty` 时，下一拍读指针加 1；
- 空读时 `rd_error=1`；
- 没有空读请求时 `rd_error=0`。

### 9.5 指针回卷

- 指针低地址位从 `depth-1` 回到 0；
- 地址回卷时扩展最高位正确翻转；
- 指针每次最多只增加 1。

写断言时要注意 SVA 在时钟沿采样的是非阻塞赋值更新前的值，因此需要根据实际时序选择 `|->`、`|=>` 或 `$past()`。

## 10. 功能覆盖率

### 10.1 基本请求覆盖

```text
wr_en = 0/1
rd_en = 0/1
```

需要覆盖四种读写组合：

```text
空闲
只写
只读
同时读写
```

### 10.2 状态和请求交叉覆盖

至少需要：

```text
full × wr_en × rd_en
empty × wr_en × rd_en
```

重点确认：

- 满状态写入；
- 满状态同拍读写；
- 空状态读取；
- 空状态同拍读写。

### 10.3 FIFO 水位

scoreboard 可以根据 queue size 采集水位：

```text
0
1
2 到 depth-2
depth-1
depth
```

### 10.4 其他覆盖

- `wr_error` 和 `rd_error`；
- 写指针回卷；
- 读指针回卷；
- 初始复位和运行中复位；
- 单次、短 burst 和长度大于 depth 的 burst。

## 11. 参数回归

合法配置计划：

| 配置 | width | depth |
|---|---:|---:|
| 最小深度 | 8 | 2 |
| 小深度 | 8 | 4 |
| 中等深度 | 8 | 8 |
| 默认配置 | 8 | 16 |
| 深 FIFO | 8 | 32 |
| 单 bit 数据 | 1 | 16 |
| 宽数据 | 32 | 16 |

非法参数测试：

```text
width = 0
depth = 0
depth = 1
depth = 3
depth = 6
depth = 12
```

非法配置的预期结果是 `$fatal`，不能把这种预期失败统计成回归失败。

## 12. 故障注入

为了证明平台能够发现问题，计划通过故意修改 DUT 进行故障注入，并确认对应测试能够失败。

| 编号 | 故意加入的问题 | 应该由什么发现 |
|---|---|---|
| M01 | 删除 full 判断中的最高位比较 | full test / scoreboard / SVA |
| M02 | 满写时仍然移动写指针 | overflow test / SVA |
| M03 | 满写时仍然写 RAM | overflow test / scoreboard |
| M04 | 空读时把 `rd_data` 清零 | underflow test / SVA |
| M05 | 读数据使用移动后的下一个地址 | scoreboard |
| M06 | `wr_error` 直接等于 full | error test / scoreboard |
| M07 | `rd_error` 直接等于 empty | error test / scoreboard |
| M08 | 复位时不清读写指针 | reset test / SVA |
| M09 | 写指针加 2 | ordering test / SVA |
| M10 | 删除 depth 为 2 的幂的参数检查 | invalid parameter test |

## 13. 回归计划

回归脚本需要：

1. 依次运行所有 testcase；
2. 对随机测试运行多个 seed；
3. 解析日志中的 UVM error、fatal 和 assertion failure；
4. 输出每个测试的 PASS/FAIL；
5. 只要有一个测试失败，脚本退出码就不是 0；
6. 对非法参数测试单独判断预期 `$fatal`。

随机回归建议：

```text
默认配置随机测试：至少 20 个 seed
depth=2：至少 10 个 seed
depth=4：至少 10 个 seed
width=32：至少 10 个 seed
```

## 14. 完成标准

满足下面条件后，可以认为这个 FIFO 验证项目完成：

- [ ] 所有 P0 和 P1 Feature 都有对应测试；
- [ ] 所有功能测试自动 PASS；
- [ ] scoreboard 数据 mismatch 为 0；
- [ ] UVM error 和 fatal 为 0；
- [ ] SVA 没有未解释的失败；
- [ ] 功能覆盖率达到 95% 以上；
- [ ] 没有覆盖到的 bin 有明确原因；
- [ ] 所有合法参数配置通过；
- [ ] 所有非法参数配置都按预期被拒绝；
- [ ] 至少 10 个故障注入都能被平台发现；
- [ ] 一条命令可以完成回归并汇总结果。

## 15. 当前验证范围之外的内容

当前项目不验证：

- 异步 FIFO 和跨时钟域；
- 非 2 的幂深度的正常功能；
- FWFT 读模式；
- 空状态读写旁路；
- 满状态零气泡读写；
- FPGA 或 ASIC RAM 宏的具体物理时序。
