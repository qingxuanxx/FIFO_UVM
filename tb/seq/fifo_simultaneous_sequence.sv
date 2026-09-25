class fifo_simultaneous_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_simultaneous_sequence)

    localparam int unsigned fifo_depth = 16;
    localparam int unsigned simultaneous_cycles = 2 * fifo_depth;

    function new(string name = "fifo_simultaneous_sequence");
        super.new(name);
    endfunction

    task body();
        int unsigned i;

        // 非空非满：保留 1 个数据，连续同拍读写，验证深度不变
        run_nonfull_case(1, 8'h10, 8'h40);

        // 非空非满：保留 depth-1 个数据，重复同拍读写
        run_nonfull_case(fifo_depth - 1, 8'h20, 8'h80);

        // 空时同拍读写：写入成功，读出失败（预期 rd_error 拉高）
        `uvm_info("TC_SIMULTANEOUS", "Simultaneous read/write while empty", UVM_LOW)
        send_fifo_request(1'b1, 1'b1, 8'hD1);
        // 下一拍 FIFO 非空，读出刚才写入的 D1
        send_fifo_request(1'b0, 1'b1, 8'h00);
        send_fifo_request(1'b0, 1'b0, 8'h00);

        // 满时同拍读写：读出成功，写入失败（预期 wr_error 拉高）
        `uvm_info("TC_SIMULTANEOUS", "Simultaneous read/write while full", UVM_LOW)
        for (i = 0; i < fifo_depth; i++) begin
            send_fifo_request(1'b1, 1'b0, i + 1);
        end

        send_fifo_request(1'b1, 1'b1, 8'hEE);  // 当前 FIFO 已满，同拍读写

        // 同拍操作中的读已经取走队首，因此剩下 depth-1 个数据
        for (i = 0; i < fifo_depth - 1; i++) begin
            send_fifo_request(1'b0, 1'b1, 8'h00);
        end

        send_fifo_request(1'b0, 1'b0, 8'h00);
    endtask

    // 辅助任务：非空非满状态下的同拍读写测试
    // run_nonfull_case 任务最后会把数据读空。因此，当进入下一个场景时，FIFO 必定处于空状态
    task run_nonfull_case(
        input int unsigned initial_count,
        input bit [7:0] initial_base,
        input bit [7:0] stream_base
    );
        int unsigned i;
        bit [7:0] wr_data;

        `uvm_info(
            "TC_SIMULTANEOUS",
            $sformatf("Keep %0d items during simultaneous traffic", initial_count),
            UVM_LOW
        )

        // 先写入 initial_count 个数据
        for (i = 0; i < initial_count; i++) begin
            wr_data = initial_base + i;
            send_fifo_request(1'b1, 1'b0, wr_data);
        end

        // 每拍同时读写，FIFO 中的数据个数应保持不变
        for (i = 0; i < simultaneous_cycles; i++) begin
            wr_data = stream_base + i;
            send_fifo_request(1'b1, 1'b1, wr_data);
        end

        // 读完剩余数据，scoreboard 检查顺序
        for (i = 0; i < initial_count; i++) begin
            send_fifo_request(1'b0, 1'b1, 8'h00);
        end
    endtask

endclass