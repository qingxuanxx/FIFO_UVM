class fifo_single_wr_rd_test extends fifo_base_test;

    `uvm_component_utils(fifo_single_wr_rd_test)

    function new(string name = "fifo_single_wr_rd_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // run_phase：测试用例的执行主体，整个仿真期间一直运行
    task run_phase(uvm_phase phase);

        // 声明 sequence 句柄（注意：这里只声明，不要在这里 new）
        fifo_single_wr_rd_sequence seq;

        // 作用：告诉 UVM 调度器“我还在干活，先别结束仿真”
        // 因为 run_phase 是个耗时任务，不加这个，仿真可能瞬间就跑到 $finish 了
        phase.raise_objection(this);

        // 通过 factory 机制创建 sequence 实例
        seq = fifo_single_wr_rd_sequence::type_id::create("seq");

        // 将 sequence 挂载到 Sequencer 上启动
        // 序列一旦启动，其中的 `start_item` 和 `finish_item` 就会通过 sequencer 与 driver 进行握手
        seq.start(env.agent.sequencer);

        // 等一个 monitor 上升沿，让最后的采样处理完成
        @(vif.mon_cb);

        `uvm_info("TC_SINGLE_WR_RD", "Test completed", UVM_LOW)

        // 作用：告诉 UVM 调度器“我的活干完了，如果没有其他反对票，仿真可以结束了”
        phase.drop_objection(this);

    endtask

endclass
