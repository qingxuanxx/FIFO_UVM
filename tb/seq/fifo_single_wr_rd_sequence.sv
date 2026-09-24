class fifo_single_wr_rd_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_single_wr_rd_sequence)

    function new(string name = "fifo_single_wr_rd_sequence");
        super.new(name);
    endfunction

    // 核心任务：定义测试序列的具体流程
    task body();
        // --- 场景 1：写入非零数据 A5，然后读出 ---
        `uvm_info("TC_SINGLE_WR_RD", "Test nonzero data", UVM_LOW)
        send_fifo_request(1'b1, 1'b0, 8'hA5); // 写入 A5
        send_fifo_request(1'b0, 1'b1, 8'h00); // 读出 A5

        // --- 场景 2：写入零数据 00，然后读出 ---
        // 为什么还要测 00？为了覆盖数据域的边界情况，防止 RTL 里出现“数据为0时丢失”的隐藏 bug
        `uvm_info("TC_SINGLE_WR_RD", "Test zero data", UVM_LOW)
        send_fifo_request(1'b1, 1'b0, 8'h00); // 写入 00
        send_fifo_request(1'b0, 1'b1, 8'h00); // 读出 00

        // 显式发送空闲请求，让 driver 把接口信号置为 0
        send_fifo_request(1'b0, 1'b0, 8'h00);

    endtask

endclass
