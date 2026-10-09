class fifo_random_sequence extends fifo_base_sequence;

    `uvm_object_utils(fifo_random_sequence)

    localparam int unsigned FIFO_DEPTH = 16;

    // 根据已发送的请求计算剩余数据量，仅用于最后读空
    int unsigned occupancy;

    function new(string name = "fifo_random_sequence");
        super.new(name);
    endfunction

    task body();
        int unsigned remaining;

        // 本 test 从初始复位后的空 FIFO 开始
        occupancy = 0;

        run_random_phase(600, 5, 5);
        run_random_phase(200, 8, 2);
        run_random_phase(200, 2, 8);

        remaining = occupancy;

        `uvm_info(
            "TC_RANDOM",
            $sformatf("Drain %0d remaining items", remaining),
            UVM_LOW
        )

        repeat (remaining) begin
            send_fifo_request(1'b0, 1'b1, 8'h00);
        end

        occupancy = 0;

        send_fifo_request(1'b0, 1'b0, 8'h00);
    endtask

    task run_random_phase(
        input int unsigned count,
        input int unsigned wr_weight,
        input int unsigned rd_weight
    );
        fifo_item item;
        bit wr_success;
        bit rd_success;

        `uvm_info(
            "TC_RANDOM",
            $sformatf(
                "Random phase: cycles=%0d, write=%0d%%, read=%0d%%",
                count, wr_weight * 10, rd_weight * 10
            ),
            UVM_LOW
        )

        repeat (count) begin
            item = fifo_item::type_id::create("item");

            start_item(item);

            // 带权重随机化：local:: 用于引用外层的参数
            if (!item.randomize() with {
                wr_en dist {
                    1 := local::wr_weight,
                    0 := (10 - local::wr_weight)
                };

                rd_en dist {
                    1 := local::rd_weight,
                    0 := (10 - local::rd_weight)
                };
            }) begin
                `uvm_fatal("RAND_FAILED", "FIFO request randomization failed")
            end

            finish_item(item);

            // 两个条件都根据操作前的数据量计算
            wr_success = item.wr_en && (occupancy < FIFO_DEPTH);
            rd_success = item.rd_en && (occupancy > 0);

            if (wr_success)
                occupancy++;

            if (rd_success)
                occupancy--;
        end
    endtask

endclass
