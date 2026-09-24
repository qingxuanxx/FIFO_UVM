class fifo_base_sequence extends uvm_sequence #(fifo_item);

    function new(string name = "fifo_base_sequence");
        super.new(name);
    endfunction

    task send_fifo_request(
        bit wr,
        bit rd,
        bit [7:0] wr_data
    );

        fifo_item item;

        // 1. 通过工厂机制创建 item 实例
        item = fifo_item::type_id::create("item");

        // 2. 向 Sequencer 申请发送权限（开始握手）
        start_item(item);

        // 3. 对 item 进行赋值（这里没有用随机化，完全是定向控制）
        item.wr_en = wr;
        item.rd_en = rd;
        item.wr_data = wr_data;

        // 4. 发送完成，通知 Sequencer 可以交给 Driver 驱动了（结束握手）
        finish_item(item);

    endtask

endclass
