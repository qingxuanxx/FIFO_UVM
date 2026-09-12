class fifo_agent extends uvm_agent;
    
    `uvm_component_utils(fifo_agent)

    // agent 内部的两个组件
    fifo_sequencer sequencer;
    fifo_driver driver;

    function new(string name = "fifo_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 创建子组件
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = fifo_sequencer::type_id::create("sequencer", this);
        driver = fifo_driver::type_id::create("driver", this);

    endfunction

    // 连接子组件之间的通信端口
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        driver.seq_item_port.connect(sequencer.seq_item_export);

    endfunction

endclass