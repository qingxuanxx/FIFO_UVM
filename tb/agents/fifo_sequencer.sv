class fifo_sequencer extends uvm_sequencer #(fifo_item);

    // 注册到 uvm factory
    `uvm_component_utils(fifo_sequencer)

    // 构造函数
    function new(string name = "fifo_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass