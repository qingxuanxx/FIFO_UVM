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

    // 独立的 reference model
    fifo_reference_model model;

    // 已经收到的sample数量
    int unsigned received_count = 0;

    int unsigned pass_count = 0;
    int unsigned mismatch_count = 0;

    // 构造函数
    function new(string name = "fifo_scoreboard", uvm_component parent = null);
        super.new(name, parent);

        // 创建接收端，并指定由当前 scoreboard 处理数据
        analysis_export = new("analysis_export", this);

    endfunction

    // 在 build 阶段创建 reference model
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        // model 是 object，所以 create() 没有 parent
        model = fifo_reference_model::type_id::create("model");

    endfunction

    // monitor 每发送一个 sample，就调用一次
    function void write(fifo_monitor_item sample);

        fifo_expected_item expected;

        received_count ++;

        // 调用 reference model 来计算预期结果
        expected = model.predict(sample);

        // if (sample.rst === 1'b1) begin
        //     `uvm_info("FIFO_SCOREBOARD", "Received reset sample", UVM_LOW)
        // end
        // else begin
        //     `uvm_info("FIFO_SCOREBOARD", sample.convert2string(), UVM_LOW)
        // end

        if (sample.rst === 1'b1) begin
            `uvm_info("FIFO_SCOREBOARD", "Reference model reset", UVM_LOW)

            return;
            // 当仿真处于复位期间（rst=1）时，DUT 内部的信号（如 rd_data、full、empty）可能是不定态（X），或者是没有意义的初始值
            // 如果此时还去执行后面的 if (actual !== expected) 比对逻辑，会导致仿真里疯狂爆出无意义的误报
            // return; 的作用就是：
            // “复位周期，向 Scoreboard 打个报告（清空队列），然后就立刻退出这个 write 函数，不参与后面的比对
        end

        // 直接一次比较所有需要检查的结果
        if ({
            sample.pre_full, sample.pre_empty,
            sample.rd_data, sample.wr_error, sample.rd_error,
            sample.post_full, sample.post_empty
        } !== {
            expected.pre_full, expected.pre_empty,
            expected.rd_data, expected.wr_error, expected.rd_error,
            expected.post_full, expected.post_empty
        }) begin
            mismatch_count ++;

            `uvm_error("FIFO_MISMATCH", $sformatf("actual: %s, expected:%s", sample.convert2string(), expected.convert2string()))
        end
        else begin
            pass_count ++;

            `uvm_info("FIFO_SCOREBOARD", $sformatf("PASS: %s", sample.convert2string()), UVM_LOW)
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

        `uvm_info("FIFO_SCOREBOARD", $sformatf("Received %0d samples, passed=%0d, mismatches=%0d", received_count, pass_count, mismatch_count), UVM_LOW)

    endfunction

endclass
