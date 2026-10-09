class fifo_wraparound_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_wraparound_sequence)

    // 当前先使用默认深度
    localparam int unsigned FIFO_DEPTH = 16;
    localparam int unsigned NUM_ROUNDS = 6;

    function new(string name = "fifo_wraparound_sequence");
        super.new(name);
    endfunction

    task body();
        int unsigned round;
        int unsigned i;
        bit [7:0] wr_data;

        for (round = 0; round < NUM_ROUNDS; round++) begin

            `uvm_info(
                "TC_WRAPAROUND",
                $sformatf("Round %0d: fill FIFO", round + 1),
                UVM_LOW
            )

            // 连续写满
            for (i = 0; i < FIFO_DEPTH; i++) begin
                wr_data = round * FIFO_DEPTH + i + 1;
                send_fifo_request(1'b1, 1'b0, wr_data);
            end

            `uvm_info(
                "TC_WRAPAROUND",
                $sformatf("Round %0d: drain FIFO", round + 1),
                UVM_LOW
            )

            // 连续读空，由 scoreboard 检查结果
            for (i = 0; i < FIFO_DEPTH; i++) begin
                send_fifo_request(1'b0, 1'b1, 8'h00);
            end
        end

        // 最后将接口置为空闲
        send_fifo_request(1'b0, 1'b0, 8'h00);

    endtask

endclass
