# 同步 FIFO 设计规格说明

## 1. 设计目标

设计一个单时钟同步 FIFO，用来暂存数据。数据写进去以后，要按照先进先出的顺序读出来。

主要实现下面这些功能：

- 支持连续写入和连续读取；
- FIFO 满了以后不能继续写，防止旧数据被覆盖；
- FIFO 空了以后不能继续读；
- 可以同时进行读操作和写操作；
- 通过 `full` 和 `empty` 表示 FIFO 当前状态；
- 非法读写时，通过 error 信号提示。

## 2. 参数

FIFO 有两个参数：

```systemverilog
parameter int width = 8;
parameter int depth = 16;
```

其中：

- `width` 表示一个数据的位宽，默认是 8 bit；
- `depth` 表示 FIFO 最多能保存多少个数据，默认是 16 个。

参数需要满足：

```text
width >= 1
depth >= 2
depth 必须是 2 的幂
```

所以 `depth` 可以取 2、4、8、16、32 等，不能取 3、6、12 等数值。

地址和指针位宽计算如下：

```systemverilog
addr_width = $clog2(depth);
ptr_width  = addr_width + 1;
```

指针的最高位用来判断 FIFO 是空还是满，其他低位作为 RAM 地址。

如果参数不合法，在仿真开始时使用 `$fatal` 停止仿真。

## 3. 接口信号

| 信号 | 方向 | 位宽 | 作用 |
|---|---|---:|---|
| `clk` | in | 1 | FIFO 工作时钟 |
| `rst` | in | 1 | 高电平有效的异步复位 |
| `wr_en` | in | 1 | 写使能 |
| `wr_data` | in | `width` | 要写入 FIFO 的数据 |
| `rd_en` | in | 1 | 读使能 |
| `rd_data` | out | `width` | 从 FIFO 读出的数据 |
| `full` | out | 1 | FIFO 满标志 |
| `empty` | out | 1 | FIFO 空标志 |
| `wr_error` | out | 1 | FIFO 满的时候仍然写入 |
| `rd_error` | out | 1 | FIFO 空的时候仍然读取 |

## 4. 复位

高电平有效的异步复位：

```systemverilog
always_ff @(posedge clk or posedge rst)
```

所以 `rst` 从 0 变成 1 时，不需要等待时钟上升沿，FIFO 会直接复位。

复位时：

```text
写指针 wr_ptr = 0
读指针 rd_ptr = 0
读数据 rd_data = 0
写错误 wr_error = 0
读错误 rd_error = 0
empty = 1
full = 0
```

不需要在复位时清空 RAM。因为复位后读写指针相同，FIFO 已经是空状态，RAM 里面以前的数据会被认为是无效数据。

复位期间不进行读写操作。复位释放后，从下一个时钟上升沿开始正常工作。

## 5. FIFO 存储器和指针

FIFO 内部使用一个寄存器数组保存数据：

```systemverilog
logic [width-1:0] mem [depth-1:0];
```

读写指针的位宽都是：

```text
ptr_width = addr_width + 1
```

例如 `depth=16`：

```text
addr_width = 4
ptr_width  = 5
```

指针低 4 位作为 RAM 地址，最高位表示指针是否已经回卷。写指针和读指针通过固定宽度加一自然回卷。

## 6. 写操作

写操作的有效条件是：

```systemverilog
wr_valid = wr_en && !full;
```

当 `wr_en=1` 并且 FIFO 没满时，在 `clk` 上升沿：

1. 把 `wr_data` 写到当前写指针对应的 RAM 地址；
2. 写指针加 1；
3. `wr_error` 保持为 0。

如果 FIFO 没满，`wr_en` 可以连续拉高，每个时钟周期写入一个数据。

### FIFO 满时写入

当 `wr_en=1` 并且 `full=1` 时：

- 这次写操作不成功；
- RAM 里的数据不能被覆盖；
- 写指针保持不变；
- `wr_error` 在这个时钟沿以后变成 1。

如果连续多拍在满状态下写，`wr_error` 可以连续多拍为 1。

## 7. 读操作

读操作的有效条件是：

```systemverilog
rd_valid = rd_en && !empty;
```

当 `rd_en=1` 并且 FIFO 非空时，在 `clk` 上升沿：

1. 从当前读指针对应的 RAM 地址读取数据；
2. 读出的数据更新到 `rd_data`；
3. 读指针加 1；
4. `rd_error` 保持为 0。

只有读操作有效时，`rd_data` 才会更新。

当 FIFO 非空但是 `rd_en=0` 时，`rd_data` 保持原来的值，不会自动显示当前队头。

### FIFO 空时读取

当 `rd_en=1` 并且 `empty=1` 时：

- 这次读操作不成功；
- 读指针保持不变；
- `rd_data` 保持原来的值；
- `rd_error` 在这个时钟沿以后变成 1。

## 8. 空满判断

### 空判断

当读写指针所有位都相同时，说明 FIFO 为空：

```systemverilog
assign empty = (wr_ptr == rd_ptr);
```

### 满判断

当读写指针的地址部分相同，但是最高位不同时，说明写指针比读指针多走了一圈，FIFO 已满：

```systemverilog
assign full =
    (wr_ptr[ptr_width-1] != rd_ptr[ptr_width-1]) &&
    (wr_ptr[ptr_width-2:0] == rd_ptr[ptr_width-2:0]);
```

FIFO 一共可以保存完整的 `depth` 个数据。

写入第 `depth` 个数据以后，`full` 变成 1。读出最后一个数据以后，`empty` 变成 1。

正常情况下，`full` 和 `empty` 不能同时为 1。

## 9. 同时读写

读写是否有效，都是根据时钟上升沿之前的 `full` 和 `empty` 独立判断。

| FIFO 当前状态 | `wr_en` | `rd_en` | 写操作 | 读操作 | FIFO 数据数量变化 |
|---|---:|---:|---|---|---:|
| 普通状态 | 0 | 0 | 无 | 无 | 0 |
| 普通状态 | 1 | 0 | 成功 | 无 | +1 |
| 普通状态 | 0 | 1 | 无 | 成功 | -1 |
| 普通状态 | 1 | 1 | 成功 | 成功 | 0 |
| 空状态 | 1 | 1 | 成功 | 失败 | +1 |
| 满状态 | 1 | 1 | 失败 | 成功 | -1 |

### 普通状态同时读写

FIFO 非空非满时，如果 `wr_en` 和 `rd_en` 同时为 1，读写都成功。读写指针都加 1，FIFO 中的数据数量不变。

### 空状态同时读写

FIFO 为空时，如果 `wr_en` 和 `rd_en` 同时为 1：

- 写操作成功；
- 读操作失败；
- `rd_error=1`；
- 新写入的数据不会在同一拍直接输出；
- 写入以后 FIFO 不再为空。

### 满状态同时读写

FIFO 已满时，如果 `wr_en` 和 `rd_en` 同时为 1：

- 写操作失败；
- 读操作成功；
- `wr_error=1`；
- 读出一个数据以后 FIFO 不再满；
- 这次被拒绝的写数据不会写入 FIFO。

## 10. Error 信号

error 信号设计成寄存器输出：

```systemverilog
wr_error <= wr_en && full;
rd_error <= rd_en && empty;
```

它们表示当前时钟沿的读写请求有没有被拒绝。

因此：

- FIFO 满，但 `wr_en=0` 时，`wr_error=0`；
- FIFO 空，但 `rd_en=0` 时，`rd_error=0`；
- FIFO 满且请求写入时，`wr_error=1`；
- FIFO 空且请求读取时，`rd_error=1`。

error 不是 `full` 和 `empty` 的直接复制。

## 11. 数据要求

- 数据必须按照写入顺序读出；
- 满状态下被拒绝的数据不能进入 FIFO；
- 空状态下的读操作不能改变读指针和输出数据；
- 没有复位时，已经成功写入但还没有读出的数据不能丢失；
- 读写指针多次回卷以后，数据顺序仍然要正确；
- 复位以后，复位前还没有读出的数据全部作废。

## 12. 不支持的情况

当前设计不支持：

- `depth` 不是 2 的幂；
- FWFT 读模式；
- FIFO 空时同拍读写直接旁路；
- FIFO 满时利用同拍读取释放的空间完成写入；
- 运行过程中修改 `width` 或 `depth`；
- 异步 FIFO 和跨时钟域传输。

## 13. 后续验证内容

完成 RTL 后，我需要验证下面这些场景：

- [ ] 复位后 `empty=1`、`full=0`
- [ ] 单次写入和读取的数据正确
- [ ] 连续写入和连续读取的数据顺序正确
- [ ] 写满 `depth` 个数据以后 `full=1`
- [ ] FIFO 满时继续写，写指针和原数据保持
- [ ] 读出最后一个数据以后 `empty=1`
- [ ] FIFO 空时继续读，读指针和 `rd_data` 保持
- [ ] 普通状态同时读写都成功
- [ ] 空状态同时读写只有写成功
- [ ] 满状态同时读写只有读成功
- [ ] `wr_error` 和 `rd_error` 时序正确
- [ ] 读写指针至少回卷三次，数据顺序仍然正确
- [ ] 非法参数能够通过 `$fatal` 检查出来
