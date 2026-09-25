class fifo_simultaneous_test extends fifo_base_test;

    `uvm_component_utils(fifo_simultaneous_test)

    function new(
        string name = "fifo_simultaneous_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_simultaneous_sequence seq;

        phase.raise_objection(this);

        seq = fifo_simultaneous_sequence::type_id::create("seq");

        seq.start(env.agent.sequencer);

        // 等 monitor 完成最后一拍采样
        @(vif.mon_cb);

        `uvm_info("TC_SIMULTANEOUS", "Test completed", UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass
