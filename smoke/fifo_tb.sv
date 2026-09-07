`timescale 1ns/1ps

module fifo_tb;
    // 参数
    localparam int width = 8;
    localparam int depth = 16;

    // 信号
    logic clk;
    logic rst;

    logic wr_en;
    logic [width-1:0] wr_data;

    logic rd_en;
    logic [width-1:0] rd_data;

    logic full;
    logic empty;

    logic wr_error;
    logic rd_error;

    // 实例化
    fifo #(
        .width(width),
        .depth(depth)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .full(full),
        .empty(empty),
        .wr_error(wr_error),
        .rd_error(rd_error)
    );

    // 时钟，周期 10ns
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 波形
    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);
    end

    // 打印信号
    initial begin
        $monitor("Time: %0t | rst=%b | wr_en=%b | wr_data=%h | rd_en=%b | rd_data=%h | full=%b | empty=%b | wr_error=%b | rd_error=%b | wr_ptr=%0d | rd_ptr=%0d",
                 $time, rst, wr_en, wr_data,
                 rd_en, rd_data, full, empty,
                 wr_error, rd_error, dut.wr_ptr, dut.rd_ptr);
    end

    integer i;

    // 测试
    initial begin
        // 初始化
        rst = 1'b1;
        wr_en = 1'b0;
        rd_en = 1'b0;
        wr_data = '0;

        // 保持复位两个时钟周期
        repeat (2) @(posedge clk);

        // 在下降沿释放复位
        @(negedge clk);
        rst = 1'b0;

        // 场景1：空状态读取

        $display("\n=== 场景1：空状态读取 ===");

        @(negedge clk);
        rd_en = 1'b1;

        // 保持一个完整周期
        @(negedge clk);
        rd_en = 1'b0;

        if (empty)
            $display("FIFO 仍然为空");

        if (rd_error)
            $display("空读产生 rd_error");

        // 再等待一个周期，使 rd_error 清零
        @(negedge clk);

        //场景2：写满 FIFO

        $display("\n=== 场景2：写满 FIFO ===");

        wr_en = 1'b1;

        for (i = 0; i < depth; i = i + 1) begin
            wr_data = i + 1;
            @(negedge clk);
        end

        wr_en = 1'b0;

        if (full)
            $display("FIFO 已满");

        @(negedge clk);

        // 场景3：满状态继续写

        $display("\n=== 场景3：满状态继续写 ===");

        wr_en   = 1'b1;
        wr_data = 8'hEE;

        // 保持一个周期
        @(negedge clk);
        wr_en = 1'b0;

        if (wr_error)
            $display("满写产生 wr_error");

        // 再等待一个周期，使 wr_error 清零
        @(negedge clk);

        // 场景4：普通状态同时读写

        $display("\n=== 场景4：普通状态同时读写 ===");

        // FIFO 当前为满，先读出一个数据，使其进入非满状态
        rd_en = 1'b1;

        @(negedge clk);

        // 从这一拍开始同时读写
        wr_en = 1'b1;
        rd_en = 1'b1;

        for (i = 0; i < 10; i = i + 1) begin
            wr_data = 8'h20 + i;
            @(negedge clk);
        end

        wr_en = 1'b0;
        rd_en = 1'b0;

        $display("普通状态同时读写测试完成");

        @(negedge clk);

        // 场景5：随机读写

        $display("\n=== 场景5：随机读写 ===");

        for (i = 0; i < 50; i = i + 1) begin
            wr_en   = $urandom_range(0, 1);
            rd_en   = $urandom_range(0, 1);
            wr_data = $urandom_range(0, (1 << width) - 1);

            @(negedge clk);
        end

        wr_en = 1'b0;
        rd_en = 1'b0;

        $display("随机读写测试完成");

        @(negedge clk);

        // 场景6：清空 FIFO

        $display("\n=== 场景6：清空 FIFO ===");

        rd_en = 1'b1;

        while (!empty) begin
            @(negedge clk);
        end

        rd_en = 1'b0;

        if (empty)
            $display("FIFO 已经清空");

        @(negedge clk);

        $display("\n=== 所有测试完成，仿真结束 ===");

        $finish;

    end

    initial begin
        // 设置仿真时间上限，防止死循环
        #10000;
        $fatal(1, "Simulation timeout");
    end

endmodule
