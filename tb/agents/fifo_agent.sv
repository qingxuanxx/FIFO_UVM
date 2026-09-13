class fifo_agent extends uvm_agent;
    
    `uvm_component_utils(fifo_agent)

    // 声明 agent 内部的3个组件
    fifo_sequencer sequencer;
    fifo_driver driver;
    fifo_monitor monitor;

    // agent 对外暴露 monitor 的 analysis_port
    uvm_analysis_port #(fifo_monitor_item) analysis_port;

    function new(string name = "fifo_agent", uvm_component parent = null);
        super.new(name, parent);

        // 创建 agent 的 analysis port
        analysis_port = new("analysis_port", this);

    endfunction

    // 创建子组件
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = fifo_sequencer::type_id::create("sequencer", this);
        driver = fifo_driver::type_id::create("driver", this);
        monitor = fifo_monitor::type_id::create("monitor", this);

    endfunction

    // 连接子组件之间的通信端口
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // sequencer 和 driver 之间的连接
        driver.seq_item_port.connect(sequencer.seq_item_export);

        // monitor 的采样结果转发到 agent 对外的端口
        monitor.analysis_port.connect(this.analysis_port);  // this.analysis_port 指的是类成员变量

    endfunction

endclass