class fifo_burst_test extends fifo_base_test;

    `uvm_component_utils(fifo_burst_test)

    function new(string name = "fifo_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);

        // 声明突发序列句柄
        fifo_burst_sequence seq;

        phase.raise_objection(this);  // 提起 objection

        // 通过 factory 创建序列实例
        seq = fifo_burst_sequence::type_id::create("seq");

        // 将序列挂载到 sequencer 上启动
        // 序列内部的 start_item/finish_item 会自动与 driver 握手
        seq.start(env.agent.sequencer);

        // 等 monitor 再采样一拍后结束 test
        @(vif.mon_cb);

        `uvm_info("TC_BURST", "Test completed", UVM_LOW)

        // 放下 objection
        phase.drop_objection(this);

    endtask

endclass
