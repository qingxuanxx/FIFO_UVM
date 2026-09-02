module my_fifo #(
  parameter int width = 8,
  parameter int depth = 16
) (
  input logic clk,
  input logic rst,

  // 写接口
  input logic wr_en,
  input logic [width-1:0] wr_data,
  
  // 读接口
  input logic rd_en,
  output logic [width-1:0] rd_data,

  // 状态信号
  output logic full,
  output logic empty,

  // 非法操作指示
  output logic wr_error,
  output logic rd_error
);

localparam int addr_width = $clog2(depth);  // 计算地址宽度
localparam int ptr_width = addr_width + 1; // 指针宽度

logic [ptr_width-1:0] wr_ptr;
logic [ptr_width-1:0] rd_ptr;

logic [width-1:0] mem [depth-1:0]; // FIFO 存储器

logic wr_valid;
logic rd_valid;

// 参数合法性检查
initial begin
    if (width < 1)
        $fatal(1, "Width must be at least 1");

    if (depth < 2)
        $fatal(1, "Depth must be at least 2");

    // 判断 depth 是不是 2 的幂
    if ((depth & (depth - 1)) != 0)
        $fatal(1, "Depth must be a power of 2");
end


// 满空信号判断
// 空信号：读写指针的所有位相同
assign empty = (wr_ptr == rd_ptr);
// 满信号：读写指针的最高位相反，其他位相同
assign full = (wr_ptr[ptr_width-1] != rd_ptr[ptr_width-1]) && 
              (wr_ptr[ptr_width-2:0] == rd_ptr[ptr_width-2:0]);

//读写有效性
assign wr_valid = wr_en && !full;
assign rd_valid = rd_en && !empty;

// 读写操作
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr <= '0;
        rd_ptr <= '0;
        rd_data <= '0;
        wr_error <= 1'b0;
        rd_error <= 1'b0;
    end
    else begin
        // 每个周期重新计算错误状态
        wr_error <= wr_en && full; // 写入错误：写使能且 FIFO 满
        rd_error <= rd_en && empty; // 读取错误：读使能且 FIFO 空

        // 写操作
        if (wr_valid) begin
            mem[wr_ptr[addr_width-1:0]] <= wr_data; // 写入数据到 FIFO
            wr_ptr <= wr_ptr + 1;
        end

        if (rd_valid) begin
            rd_data <= mem[rd_ptr[addr_width-1:0]]; // 从 FIFO 读取数据
            rd_ptr <= rd_ptr + 1;
        end
    end
end

endmodule