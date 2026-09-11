class fifo_test extends uvm_test;

    `uvm_component_utils(fifo_test)

    // 给 test 声明一个名叫 vif 的变量，用来引用数据宽度为 8 的 fifo_if 实例
    virtual fifo_if #(8) vif;

    function new(string name = "fifo_test", uvm_component parent = null);
        super.new(name, parent);  // super 表示父类，这句调用父类的构造函数
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);  // 先执行父类提供的这一阶段的处理

        // config_db::get() 
        // 为当前 test 查找名为 "vif" 的配置，并把结果保存到成员变量 vif 中
        // get() 成功返回 1，失败返回 0
        if (!uvm_config_db #(virtual fifo_if #(8))::get(
            this,  // 以当前 test 对象作为查找路径的起点
            "",  // 不再追加下级路径，就是为当前 test 查配置
            "vif",  // 要查找的配置名称
            vif  // 查到后，把接口引用存到这个变量中
        )) begin
            `uvm_fatal("NO_VIF", "Cannot get FIFO interface")
        end
    endfunction

    task run_phase(uvm_phase phase);

        // 先声明句柄
        fifo_item item;

        // UVM 不会仅因为 task 里还有一个 repeat 就自动等它执行完
        // 所以需要用 objection 表明还有工作
        phase.raise_objection(this);
            `uvm_info("FIFO_TEST", "FIFO interface obtained", UVM_LOW)

            // 通过 factory 创建对象
            item = fifo_item::type_id::create("item");

            // 手动设置一笔读写请求
            item.wr_en = 1'b1;
            item.rd_en = 1'b0;
            item.wr_data = 8'ha5;

            `uvm_info("ITEM_FIXED", item.convert2string(), UVM_LOW)

            // 随机化读写请求
            repeat (5) begin
                if (!item.randomize()) begin  // randomize() 成功返回 1，失败返回 0
                    `uvm_fatal("RAND_FAIL", "fifo_item randomization failed")
                end

                    `uvm_info("ITEM_RANDOM", item.convert2string(), UVM_LOW)
            end

            // 通过 interface 等待 6 个上升沿
            // 因为 clocking mon_cb @(posedge clk);
            repeat (6) @(vif.mon_cb);

            `uvm_info("FIFO_TEST", "Test completed", UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass
