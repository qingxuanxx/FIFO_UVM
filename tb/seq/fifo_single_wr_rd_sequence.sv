class fifo_single_wr_rd_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_single_wr_rd_sequence)

    function new(string name = "fifo_single_wr_rd_sequence");
        super.new(name);
    endfunction

    // 核心任务：定义测试序列的具体流程
    task body();
        bit [DATA_WIDTH-1:0] alternating_data;
        bit [DATA_WIDTH-1:0] data;

        // 至少测试一轮单 1、16 个递增值和16个随机值。
        // 递增值按位宽自然截断；随机值覆盖完整 DATA_WIDTH。

        // --- 场景 1：按当前位宽写入全 1，然后读出 ---
        `uvm_info("TC_SINGLE_WR_RD", "Test nonzero data", UVM_LOW)
        send_fifo_request(1'b1, 1'b0, '1); // 任意合法位宽下均为非零值
        send_fifo_request(1'b0, 1'b1, 8'h00); // 读出全 1

        // FIFO 已空，但 rd_data 应保持刚读出的全 1。
        `uvm_info("TC_SINGLE_WR_RD", "Test nonzero read-output hold while idle", UVM_LOW)
        send_fifo_request(1'b0, 1'b0, '0);

        `uvm_info("TC_SINGLE_WR_RD", "Test nonzero read-output hold during empty read", UVM_LOW)
        send_fifo_request(1'b0, 1'b1, '0);

        // --- 场景 2：写入零数据 00，然后读出 ---
        // 为什么还要测 00？为了覆盖数据域的边界情况，防止 RTL 里出现“数据为0时丢失”的隐藏 bug
        `uvm_info("TC_SINGLE_WR_RD", "Test zero data", UVM_LOW)
        // 只写零值不会更新 rd_data；成功读出零值后才更新。
        `uvm_info("TC_SINGLE_WR_RD", "Test nonzero read-output hold during write-only", UVM_LOW)
        send_fifo_request(1'b1, 1'b0, 8'h00); // 写入 00
        send_fifo_request(1'b0, 1'b1, 8'h00); // 读出 00

        // 1 位下交替模式与全 0、全 1 重复，仅在更宽配置下运行。
        if (DATA_WIDTH > 1) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                alternating_data[i] = i % 2;
            end

            `uvm_info(
                "TC_SINGLE_WR_RD",
                $sformatf("Test alternating data: %h", alternating_data),
                UVM_LOW
            )
            send_fifo_request(1'b1, 1'b0, alternating_data);
            send_fifo_request(1'b0, 1'b1, '0);

            alternating_data = ~alternating_data;
            `uvm_info(
                "TC_SINGLE_WR_RD",
                $sformatf("Test inverted alternating data: %h", alternating_data),
                UVM_LOW
            )
            send_fifo_request(1'b1, 1'b0, alternating_data);
            send_fifo_request(1'b0, 1'b1, '0);
        end

        // 单个 1 依次移动。1 位时已由全 1 场景覆盖，不重复发送。
        if (DATA_WIDTH > 1) begin
            `uvm_info("TC_SINGLE_WR_RD", "Test walking-one data", UVM_LOW)
            for (int i = 0; i < DATA_WIDTH; i++) begin
                data = '0;
                data[i] = 1'b1;
                `uvm_info(
                    "TC_SINGLE_WR_RD",
                    $sformatf("Walking-one position=%0d, data=%h", i, data),
                    UVM_LOW
                )
                send_fifo_request(1'b1, 1'b0, data);
                send_fifo_request(1'b0, 1'b1, '0);
            end
        end

        `uvm_info("TC_SINGLE_WR_RD", "Test 16 incrementing values", UVM_LOW)
        data = '0;
        repeat (16) begin
            send_fifo_request(1'b1, 1'b0, data);
            send_fifo_request(1'b0, 1'b1, '0);
            data++;
        end

        `uvm_info("TC_SINGLE_WR_RD", "Test 16 random values", UVM_LOW)
        repeat (16) begin
            if (!std::randomize(data)) begin
                `uvm_fatal("RAND_FAILED", "Data randomization failed")
            end
            send_fifo_request(1'b1, 1'b0, data);
            send_fifo_request(1'b0, 1'b1, '0);
        end

        // 显式发送空闲请求，让 driver 把接口信号置为 0
        send_fifo_request(1'b0, 1'b0, 8'h00);

    endtask

endclass
