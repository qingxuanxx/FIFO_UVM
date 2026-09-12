class fifo_sequence extends uvm_sequence #(fifo_item);
    // 注册到 uvm factory
    `uvm_object_utils(fifo_sequence)

    // 构造函数
    function new(string name = "fifo_sequence");
        super.new(name);
    endfunction

    // 把 sequence 的工作写在 body() 里面
    task body();
        // 先声明
        fifo_item item;

        // 然后创建一个 transaction
        item = fifo_item::type_id::create("item");
        // sequence 每产生一笔独立请求，通常创建一个新的 item

        start_item(item);  // 准备产生一个 item，请 sequencer 准备接收

        // 随机化这个 transaction
        if (!item.randomize()) begin
            `uvm_fatal("RAND_FAIL", "fifo_item randomization failed")
        end

        finish_item(item);  // item 已经准备好，可以把它交给 sequencer，再由 driver 取走
        // 不能在 finish_item() 后再修改 item，因为那时它已经交给 sequencer 了

    endtask

endclass