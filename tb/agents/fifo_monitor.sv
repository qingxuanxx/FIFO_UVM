class fifo_monitor extends uvm_monitor;

    // 注册到 uvm factory
    `uvm_component_utils(fifo_monitor);

    // 用来访问 top 中的 interface 实例
    virtual fifo_if #(8) vif;

    // 构造函数
    function new(string name = "fifo_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 获取 interface
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual fifo_if #(8))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "fifo_monitor cannot get FIFO interface")
        end

    endfunction

    // 每个上升沿观察接口
    task run_phase(uvm_phase phase);

        forever begin
            
            @(vif.mon_cb);  // monitor 在上升沿观察请求和执行结果

            if (vif.mon_cb.rst === 1'b1) begin  // 当前采样处于复位期间
                `uvm_info("FIFO_MONITOR", "Reset active", UVM_LOW);
            end 
            else if (vif.mon_cb.rst === 1'b0) begin

                // 先定义一个 string 变量
                string log_msg;

                // 然后在外面完成格式化，避免宏展开过长
                log_msg = $sformatf("wr_en=%b, rd_en=%b, wr_data=%h, pre_full=%b, pre_empty=%b, rd_data=%h, wr_error=%b, rd_error=%b, post_full=%b, post_empty=%b",
                    vif.mon_cb.wr_en, vif.mon_cb.rd_en, vif.mon_cb.wr_data,
                    vif.mon_cb.pre_full, vif.mon_cb.pre_empty,
                    vif.mon_cb.rd_data, vif.mon_cb.wr_error, vif.mon_cb.rd_error,
                    vif.mon_cb.post_full, vif.mon_cb.post_empty
                );

                // 打印本拍的请求，处理前状态和处理后状态
                `uvm_info("FIFO_MONITOR", log_msg, UVM_LOW);
            end

        end

    endtask;

endclass