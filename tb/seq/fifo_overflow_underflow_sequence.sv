// =====================================================================
// 定向测试序列：FIFO 溢出（Overflow）和下溢（Underflow）边界测试
// 重点验证满写（wr_error）和空读（rd_error）的断言与恢复行为
// 继承自 fifo_base_sequence，复用基类中的 send_fifo_request 方法
// =====================================================================
class fifo_overflow_underflow_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_overflow_underflow_sequence)

    // 与 DUT 及 reference model 保持一致的 FIFO 深度
    localparam int unsigned fifo_depth = DEPTH;

    // 溢出/下溢测试的连续错误拍数
    localparam int unsigned error_cycles = 3;

    function new(string name = "fifo_overflow_underflow_sequence");
        super.new(name);
    endfunction

    task body();
        int unsigned i;
        bit [DATA_WIDTH-1:0] wr_data;

        // -----------------------------------------------------------------
        // 阶段 1：填充 FIFO
        // 连续写入 fifo_depth 个数据，把 FIFO 精确写满
        // -----------------------------------------------------------------
        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Fill FIFO", UVM_LOW)
        for (i = 0; i < fifo_depth; i++) begin
            wr_data = i + 1;

            // 保证最后读出的数据非零，让后续空读能检查输出保持
            if (i == fifo_depth - 1) begin
                wr_data = '1;
            end

            send_fifo_request(1'b1, 1'b0, wr_data); // 只写不读
        end

        // -----------------------------------------------------------------
        // 阶段 2：溢出测试（写满后继续写）
        // FIFO 已满，继续写 3 个不同数据，预期 DUT 拉高 wr_error
        // -----------------------------------------------------------------
        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Write while full", UVM_LOW)
        for (i = 0; i < error_cycles; i++) begin
            wr_data = 8'hA0 + i; // 写入 A0, A1, A2，这些数据应被丢弃
            send_fifo_request(1'b1, 1'b0, wr_data);
        end

        // -----------------------------------------------------------------
        // 阶段 3：满状态空闲
        // FIFO 仍满，但不发写请求，预期 wr_error 必须清零
        // -----------------------------------------------------------------
        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Idle while full", UVM_LOW)
        send_fifo_request(1'b0, 1'b0, 8'h00);

        // -----------------------------------------------------------------
        // 阶段 4：排空 FIFO
        // 读出原先写入的 depth 个数据，验证数据未被溢出的数据污染
        // -----------------------------------------------------------------
        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Drain original FIFO data", UVM_LOW)
        for (i = 0; i < fifo_depth; i++) begin
            send_fifo_request(1'b0, 1'b1, 8'h00); // 只读不写
        end

        // -----------------------------------------------------------------
        // 阶段 5：下溢测试（读空后继续读）
        // FIFO 已空，尝试连续读取 3 拍，预期 DUT 拉高 rd_error
        // -----------------------------------------------------------------
        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Read while empty", UVM_LOW)
        for (i = 0; i < error_cycles; i++) begin
            send_fifo_request(1'b0, 1'b1, 8'h00);
        end

        // -----------------------------------------------------------------
        // 阶段 6：空状态空闲
        // FIFO 仍空，但不发读请求，预期 rd_error 必须清零
        // -----------------------------------------------------------------
        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Idle while empty", UVM_LOW)
        send_fifo_request(1'b0, 1'b0, 8'h00);

    endtask

endclass
