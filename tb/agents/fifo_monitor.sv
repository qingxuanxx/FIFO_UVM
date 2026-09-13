class fifo_monitor extends uvm_monitor;

    // 注册到 uvm factory
    `uvm_component_utils(fifo_monitor);

    // 用来访问 top 中的 interface 实例
    virtual fifo_if #(8) vif;

    // 向scoreboard发送采样结果
    uvm_analysis_port #(fifo_monitor_item) analysis_port;
    // uvm_analysis_port 是一对多广播的
    // 它发出一个数据，可以同时给 Scoreboard 做比对、给 Coverage 做采样、给 Reference Model 做参考
    // 就算现在一个接收者都没有，它也不会报错，直接丢掉数据
    //
    // #(fifo_monitor_item) 告诉 UVM：“这个喇叭只会播报 fifo_monitor_item 这种格式的包裹”
    //
    // analysis_port：实例名

    // 构造函数
    function new(string name = "fifo_monitor", uvm_component parent = null);
        super.new(name, parent);

        // 创建 analysis port
        analysis_port = new("analysis_port", this);

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

        // 声明句柄
        fifo_monitor_item sample;

        forever begin

            // 等待上升沿
            @(vif.mon_cb);  // monitor 在上升沿观察请求和执行结果

            // 1. 创建本拍的采样对象（在 forever 循环内，每次循环都要重新 create）
            sample = fifo_monitor_item::type_id::create("sample");

            if (vif.mon_cb.rst === 1'b1) begin  // 当前采样处于复位期间

                sample.rst = 1'b1;

                `uvm_info("FIFO_MONITOR", "Reset active", UVM_LOW);

                // 关键：把复位事件发出去，通知 Scoreboard 清空队列
                analysis_port.write(sample);

            end 
            else if (vif.mon_cb.rst === 1'b0) begin

                // // 先定义一个 string 变量
                // string log_msg;

                // // 然后在外面完成格式化，避免宏展开过长
                // // $sformatf：将数据按指定格式拼接成字符串并返回
                // log_msg = $sformatf("wr_en=%b, rd_en=%b, wr_data=%h, pre_full=%b, pre_empty=%b, rd_data=%h, wr_error=%b, rd_error=%b, post_full=%b, post_empty=%b",
                //     vif.mon_cb.wr_en, vif.mon_cb.rd_en, vif.mon_cb.wr_data,
                //     vif.mon_cb.pre_full, vif.mon_cb.pre_empty,
                //     vif.mon_cb.rd_data, vif.mon_cb.wr_error, vif.mon_cb.rd_error,
                //     vif.mon_cb.post_full, vif.mon_cb.post_empty
                // );

                // // 打印本拍的请求，处理前状态和处理后状态
                // `uvm_info("FIFO_MONITOR", log_msg, UVM_LOW);

                // 2. 采集复位状态（未复位）
                sample.rst = 1'b0;

                // 3. 采集上升沿之前的请求
                sample.wr_en = vif.mon_cb.wr_en;
                sample.rd_en = vif.mon_cb.rd_en;
                sample.wr_data = vif.mon_cb.wr_data;

                // 4. 采集处理之前的状态
                sample.pre_full = vif.mon_cb.pre_full;
                sample.pre_empty = vif.mon_cb.pre_empty;

                // 5. 采集处理之后的结果
                sample.rd_data = vif.mon_cb.rd_data;
                sample.wr_error = vif.mon_cb.wr_error;
                sample.rd_error = vif.mon_cb.rd_error;

                // 6. 采集处理之后的状态
                sample.post_full = vif.mon_cb.post_full;
                sample.post_empty = vif.mon_cb.post_empty;

                // 7. 打印本拍采样的结果
                `uvm_info("FIFO_MONITOR", sample.convert2string(), UVM_LOW)

                // 8. 将本拍结果发送给后续组件（scoreboard 会在这里收到）
                analysis_port.write(sample);

            end

        end

    endtask;

endclass
