class fifo_burst_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_burst_sequence)

    // 与 DUT 及 reference model 保持一致的 FIFO 深度
    // 注意：如果后续 DUT 参数化深度变了，这里也要同步修改
    localparam int unsigned fifo_depth = DEPTH;

    function new(string name = "fifo_burst_sequence");
        super.new(name);
    endfunction

    task body();

        // 依次测试长度为 1、depth-1、depth 的连续写读
        run_burst(1);
        run_burst(fifo_depth - 1);
        run_burst(fifo_depth);

        // 显式发送空闲 item，让接口回到空闲状态
        send_fifo_request(1'b0, 1'b0, 8'h00);
        // 目的：让接口回到空闲状态，防止仿真在最后一个读写操作刚发出时突然结束，
        // 导致 Monitor 来不及采样最后一拍，产生残缺比对。

    endtask

    task run_burst(input int unsigned count);
        int unsigned i;
        bit [DATA_WIDTH-1:0] wr_data;

        `uvm_info("TC_BURST", $sformatf("Run burst with %0d items", count), UVM_LOW)

        // 连续写入 count 个数据
        for (i = 0; i < count; i++) begin
            wr_data = i + 1;
            send_fifo_request(1'b1, 1'b0, wr_data);
        end

        // 连续读出 count 个数据，scoreboard 检查顺序和数据
        for (i = 0; i < count; i++) begin
            send_fifo_request(1'b0, 1'b1, 8'h00);
        end

    endtask

endclass
