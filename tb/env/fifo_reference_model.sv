class fifo_reference_model extends uvm_object;

    `uvm_object_utils(fifo_reference_model)

    // 与当前的 dut 参数一致
    localparam int depth = 16;

    // 模拟 fifo 内部保存的数据
    bit [7:0] model_q[$];

    // 模拟 dut 的 rd_data 保持行为
    // 如果本拍没有读，或者读空导致错误，held_rd_data 保持不变
    bit [7:0] held_rd_data;

    // 构造函数
    function new(string name = "fifo_reference_model");
        super.new(name);

        held_rd_data = '0;
    endfunction

    // 清空 reference model
    function void reset_model();

        model_q.delete();
        held_rd_data = '0;

    endfunction

    // 根据本拍的请求来计算预期结果
    // 仅依赖输入激励（rst/wr_en/rd_en/wr_data）独立预测，不使用 DUT 的输出信号，以确保验证的独立性
    function fifo_expected_item predict(fifo_monitor_item actual);

        fifo_expected_item expected;

        bit wr_valid;
        bit rd_valid;

        expected = fifo_expected_item::type_id::create("expected");

        expected.rst = actual.rst;

        // 复位时清空模型
        if (actual.rst === 1'b1) begin
            reset_model();

            expected.pre_full = 1'b0;
            expected.pre_empty = 1'b1;

            expected.rd_data = '0;
            expected.wr_error = 1'b0;
            expected.rd_error = 1'b0;

            expected.post_full = 1'b0;
            expected.post_empty = 1'b1;

            expected.occupancy = 0;

            // 复位结果已经计算完成，立即返回
            return expected;

        end

        // 1. 根据 model_q 计算处理之前的状态
        expected.pre_empty = (model_q.size() == 0);
        expected.pre_full = (model_q.size() == depth);

        // 2. 根据模型【自己的状态】来判断读写是否合法
        // actual 提供“外部施加了什么激励”，expected 提供“模型内部现在的状态”
        // 两者结合，才能独立推演出“预期结果”
        wr_valid = actual.wr_en && !expected.pre_full;
        rd_valid = actual.rd_en && !expected.pre_empty;

        // 3. 计算预取错误信号
        expected.wr_error = actual.wr_en && expected.pre_full;
        expected.rd_error = actual.rd_en && expected.pre_empty;

        // 4. 成功读取时，更新预期 rd_data
        if (rd_valid) begin
            held_rd_data = model_q.pop_front();
        end

        // 5. 成功写入时，数据进入队尾
        if (wr_valid) begin
            model_q.push_back(actual.wr_data);
        end

        // 6. 没有成功读取时，rd_data 依旧保持原值
        expected.rd_data = held_rd_data;

        // 7. 根据更新之后的 queue 来计算处理之后的状态
        expected.post_empty = (model_q.size() == 0);
        expected.post_full = (model_q.size() == depth);

        expected.occupancy = model_q.size();

        return expected;

    endfunction

endclass