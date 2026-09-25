class fifo_overflow_underflow_test extends fifo_base_test;

    `uvm_component_utils(fifo_overflow_underflow_test)

    function new(
        string name = "fifo_overflow_underflow_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);

        fifo_overflow_underflow_sequence seq;

        phase.raise_objection(this);

        seq = fifo_overflow_underflow_sequence::type_id::create("seq");

        seq.start(env.agent.sequencer);

        // 等 monitor 完成最后一拍采样
        @(vif.mon_cb);

        `uvm_info("TC_OVERFLOW_UNDERFLOW", "Test completed", UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass
