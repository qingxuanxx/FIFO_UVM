class fifo_scoreboard extends uvm_scoreboard;

    // 注册到uvm factory
    `uvm_component_utils(fifo_scoreboard)

    // 接受来自monitor的采样对象
    uvm_analysis_imp #(fifo_monitor_item, fifo_scoreboard) analysis_export;
    // 之前在 Monitor 里用的是 uvm_analysis_port
    // 现在 Scoreboard 里用的是 uvm_analysis_imp
    //
    // 后面的 #(fifo_monitor_item, fifo_scoreboard) 告诉 UVM：
    // “这个收件箱专门收 fifo_monitor_item 类型的包裹，而且收件人必须是 fifo_scoreboard 类。”

    // 已经收到的sample数量
    int unsigned received_count = 0;

    // 构造函数
    function new(string name = "fifo_scoreboard", uvm_component parent = null);
        super.new(name, parent);

        // 创建接收端，并指定由当前 scoreboard 处理数据
        analysis_export = new("analysis_export", this);

    endfunction

    // monitor 发送 sample 时，由analysis imp调用
    function void write(fifo_monitor_item sample);

        received_count ++;
        
        if (sample.rst === 1'b1) begin
            `uvm_info("FIFO_SCOREBOARD", "Received reset sample", UVM_LOW)
        end 
        else begin
            `uvm_info("FIFO_SCOREBOARD", sample.convert2string(), UVM_LOW)
        end

    endfunction

    // 所有run_phase阶段结束后，检查是否确实收到过数据
    function void check_phase(uvm_phase phase);

        super.check_phase(phase);

        if (received_count == 0) begin
            `uvm_error("NO_SAMPLE", "Scoreboard received no samples")
        end

    endfunction

    // 如果接收到数据，打印数量
    function void report_phase(uvm_phase phase);

        super.report_phase(phase);

        `uvm_info("FIFO_SCOREBOARD", $sformatf("Received %0d samples", received_count), UVM_LOW)

    endfunction

endclass