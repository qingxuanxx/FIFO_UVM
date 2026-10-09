class fifo_random_test extends fifo_base_test;

    `uvm_component_utils(fifo_random_test)

    function new(
        string name = "fifo_random_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_random_sequence seq;

        phase.raise_objection(this);

        seq = fifo_random_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);

        @(vif.mon_cb);

        // 用参考队列确认测试结束时已经读空
        if (env.scoreboard.model.model_q.size() != 0) begin
            `uvm_error(
                "RANDOM_NOT_DRAINED",
                "Reference queue is not empty at end of test"
            )
        end

        `uvm_info("TC_RANDOM", "Test completed", UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass
