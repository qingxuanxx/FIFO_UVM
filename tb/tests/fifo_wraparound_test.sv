class fifo_wraparound_test extends fifo_base_test;

    `uvm_component_utils(fifo_wraparound_test)

    function new(
        string name = "fifo_wraparound_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_wraparound_sequence seq;

        phase.raise_objection(this);

        seq = fifo_wraparound_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);

        // 保持测试运行，再给 monitor 一个采样周期
        @(vif.mon_cb);

        `uvm_info("TC_WRAPAROUND", "Test completed", UVM_LOW)

        phase.drop_objection(this);

    endtask

endclass
