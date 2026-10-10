`uvm_analysis_imp_decl(_expected)

class fifo_coverage extends uvm_subscriber #(fifo_monitor_item);

    `uvm_component_utils(fifo_coverage)

    // 统计正常工作期间采样的周期数
    int unsigned sample_count;

    // 第二路输入：scoreboard 比较通过后的模型结果
    uvm_analysis_imp_expected #(fifo_expected_item, fifo_coverage) expected_export;
    int unsigned occupancy_sample_count;

    typedef enum int unsigned {
        leave_empty, enter_empty, enter_full, leave_full
    } boundary_kind;

    int unsigned boundary_hits[4];

    bit previous_wr_error;
    bit previous_rd_error;
    bit error_history_valid;
    int unsigned error_sample_count;

    int unsigned write_streak;
    int unsigned read_streak;

    typedef enum int unsigned {
        idle_hold, write_only_hold, empty_read_hold
    } output_hold_kind;

    logic [DATA_WIDTH-1:0] held_read_data;
    bit held_read_valid;
    int unsigned hold_hits[3];

    // 重复 10 并按数据位宽截断；最低位为 0。
    localparam bit [DATA_WIDTH-1:0] alternating_10_pattern = {DATA_WIDTH{2'b10}};
    localparam bit [DATA_WIDTH-1:0] alternating_01_pattern = ~alternating_10_pattern;

    // 手动调用 sample()，不在这里另设时钟采样
    covergroup fifo_cg with function sample(
        bit wr_en,
        bit rd_en,
        int unsigned state
    );
        option.per_instance = 1;

        // 四种读写请求
        cp_request: coverpoint {wr_en, rd_en} {
            bins idle       = {2'b00};
            bins read_only  = {2'b01};
            bins write_only = {2'b10};
            bins read_write = {2'b11};
        }

        // 操作前的 FIFO 状态
        cp_state: coverpoint state {
            bins empty  = {0};
            bins middle = {1};
            bins full   = {2};
        }

        // 三种状态 × 四种请求，共 12 种组合
        cx_state_request: cross cp_state, cp_request;

    endgroup

    covergroup occupancy_cg with function sample(int unsigned occupancy);
        option.per_instance = 1;

        cp_occupancy: coverpoint occupancy {
            // 0～DEPTH 每个数据个数各自占一个 bin
            bins count[] = {[0:DEPTH]};
        }
    endgroup

    covergroup boundary_cg with function sample(boundary_kind kind);
        option.per_instance = 1;

        cp_boundary: coverpoint kind {
            bins empty_to_one = {leave_empty};
            bins one_to_empty = {enter_empty};
            bins almost_full_to_full = {enter_full};
            bins full_to_almost_full = {leave_full};
        }
    endgroup

    covergroup error_cg with function sample(
        bit previous_wr,
        bit current_wr,
        bit previous_rd,
        bit current_rd
    );
        option.per_instance = 1;

        cp_wr_error: coverpoint {previous_wr, current_wr} {
            bins no_error = {2'b00};
            bins rise = {2'b01};
            bins hold = {2'b11};
            bins clear = {2'b10};
        }

        cp_rd_error: coverpoint {previous_rd, current_rd} {
            bins no_error = {2'b00};
            bins rise = {2'b01};
            bins hold = {2'b11};
            bins clear = {2'b10};
        }
    endgroup

    // 只在操作成功时统计数据；四态参数保留 X/Z。
    covergroup data_cg with function sample(
        bit wr_success,
        bit rd_success,
        logic [DATA_WIDTH-1:0] wr_data,
        logic [DATA_WIDTH-1:0] rd_data
    );
        option.per_instance = 1;

        cp_wr_data: coverpoint wr_data iff (wr_success) {
            bins all_zero = {'0};
            bins all_one = {'1};
            // 1 位时交替模式就是 0/1，不增加重复的覆盖目标。
            bins alternating_10 = {alternating_10_pattern} with (DATA_WIDTH > 1);
            bins alternating_01 = {alternating_01_pattern} with (DATA_WIDTH > 1);
        }

        cp_rd_data: coverpoint rd_data iff (rd_success) {
            bins all_zero = {'0};
            bins all_one = {'1};
            bins alternating_10 = {alternating_10_pattern} with (DATA_WIDTH > 1);
            bins alternating_01 = {alternating_01_pattern} with (DATA_WIDTH > 1);
        }
    endgroup

    // 每个单 1 位置独立统计，避免枚举整个数据取值空间。
    covergroup walking_cg with function sample(int wr_index, int rd_index);
        option.per_instance = 1;

        cp_wr_position: coverpoint wr_index iff (wr_index >= 0) {
            bins position[] = {[0:DATA_WIDTH-1]};
        }
        cp_rd_position: coverpoint rd_index iff (rd_index >= 0) {
            bins position[] = {[0:DATA_WIDTH-1]};
        }
    endgroup

    covergroup data_bit_cg with function sample(
        int unsigned index,
        bit wr_success,
        bit rd_success,
        bit wr_value,
        bit rd_value
    );
        option.per_instance = 1;

        // 2*index 对应该位为 0，2*index+1 对应该位为 1。
        cp_wr_bit: coverpoint (2 * index + int'(wr_value)) iff (wr_success) {
            bins bit_value[] = {[0:2*DATA_WIDTH-1]};
        }
        cp_rd_bit: coverpoint (2 * index + int'(rd_value)) iff (rd_success) {
            bins bit_value[] = {[0:2*DATA_WIDTH-1]};
        }
    endgroup

    covergroup streak_cg with function sample(
        int unsigned write_length,
        int unsigned read_length
    );
        option.per_instance = 1;

        cp_write_streak: coverpoint write_length iff (write_length > 0) {
            bins single = {1};
            bins short_run = {[2:DEPTH]};
            bins long_run = {[DEPTH+1:$]};
        }
        cp_read_streak: coverpoint read_length iff (read_length > 0) {
            bins single = {1};
            bins short_run = {[2:DEPTH]};
            bins long_run = {[DEPTH+1:$]};
        }
    endgroup

    covergroup output_hold_cg with function sample(output_hold_kind kind);
        option.per_instance = 1;

        cp_output_hold: coverpoint kind {
            bins idle = {idle_hold};
            bins write_only = {write_only_hold};
            bins empty_read = {empty_read_hold};
        }
    endgroup

    function new(
        string name = "fifo_coverage",
        uvm_component parent = null
    );
        super.new(name, parent);

        fifo_cg = new();
        occupancy_cg = new();
        boundary_cg = new();
        error_cg = new();
        data_cg = new();
        walking_cg = new();
        data_bit_cg = new();
        streak_cg = new();
        output_hold_cg = new();
        expected_export = new("expected_export", this);
        sample_count = 0;
        occupancy_sample_count = 0;
        previous_wr_error = 0;
        previous_rd_error = 0;
        error_history_valid = 0;
        error_sample_count = 0;
        write_streak = 0;
        read_streak = 0;
        held_read_data = '0;
        held_read_valid = 0;
        foreach (hold_hits[i]) hold_hits[i] = 0;
        foreach (boundary_hits[i]) boundary_hits[i] = 0;
    endfunction

    // monitor 每广播一条记录，UVM 就调用一次 write()
    virtual function void write(fifo_monitor_item t);
        int unsigned state;

        // 必须在复位 return 前调用，才能在复位时清理历史。
        sample_errors(t);

        // 本轮只统计正常工作期间的请求
        if (t.rst === 1'b1) begin
            // 复位结束当前连续段，不能与复位后的操作拼接。
            finish_streaks();
            held_read_valid = 0;
            return;
        end

        // 防止未知值被转换成 bit，产生错误的覆盖命中
        // $isunknown 会把括号里的信号拼在一起，如果任何一个信号是 X 或 Z，条件就成立
        if ($isunknown({
            t.rst,
            t.wr_en,
            t.rd_en,
            t.pre_full,
            t.pre_empty
        })) begin
            // 状态未知时丢弃尚未结束的段，不跨未知周期拼接。
            held_read_valid = 0;
            write_streak = 0;
            read_streak = 0;
            `uvm_error(
                "COV_UNKNOWN",
                "Unknown value in FIFO coverage inputs"
            )
            return;
        end

        if (t.pre_full && t.pre_empty) begin
            held_read_valid = 0;
            write_streak = 0;
            read_streak = 0;
            `uvm_error(
                "COV_BAD_STATE",
                "FIFO cannot be full and empty at the same time"
            )
            return;
        end

        // 根据上升沿前的状态分类
        if (t.pre_empty) begin
            state = 0;
        end
        else if (t.pre_full) begin
            state = 2;
        end
        else begin
            state = 1;
        end

        // 自动采样（加 @(posedge clk)）会把复位周期的垃圾数据、甚至 X 态也统计进去
        fifo_cg.sample(t.wr_en, t.rd_en, state);

        sample_count++;

        // 上升沿前的空满状态决定本拍操作是否成功。
        // 满写、空读及无请求时，不命中对应的数据覆盖点。
        sample_data(t);
        sample_streaks(t.wr_en && !t.pre_full, t.rd_en && !t.pre_empty);
        sample_output_hold(t);
    endfunction

    function void sample_output_hold(fifo_monitor_item t);
        if ($isunknown(t.rd_data)) begin
            held_read_valid = 0;
            `uvm_error("COV_UNKNOWN_HOLD", "Unknown read output in hold coverage")
            return;
        end

        // 成功读取后更新基准；本拍是更新输出，不统计为保持。
        if (t.rd_en && !t.pre_empty) begin
            held_read_data = t.rd_data;
            held_read_valid = 1;
            return;
        end

        // 必须先成功读出非零值，且本拍实际输出与该值一致。
        // 保持是否正确仍由 scoreboard 每拍检查。
        if (!held_read_valid || held_read_data === '0 ||
            t.rd_data !== held_read_data) begin
            return;
        end

        if (!t.wr_en && !t.rd_en) begin
            output_hold_cg.sample(idle_hold);
            hold_hits[idle_hold]++;
        end
        else if (t.wr_en && !t.rd_en) begin
            output_hold_cg.sample(write_only_hold);
            hold_hits[write_only_hold]++;
        end
        else if (t.rd_en && t.pre_empty) begin
            output_hold_cg.sample(empty_read_hold);
            hold_hits[empty_read_hold]++;
        end
    endfunction

    // 一段结束后才采样长度，不把长段的前缀当成短段。
    function void sample_streaks(bit wr_success, bit rd_success);
        if (wr_success) begin
            write_streak++;
        end
        else if (write_streak > 0) begin
            streak_cg.sample(write_streak, 0);
            write_streak = 0;
        end

        if (rd_success) begin
            read_streak++;
        end
        else if (read_streak > 0) begin
            streak_cg.sample(0, read_streak);
            read_streak = 0;
        end
    endfunction

    function void finish_streaks();
        if (write_streak > 0 || read_streak > 0) begin
            streak_cg.sample(write_streak, read_streak);
        end
        write_streak = 0;
        read_streak = 0;
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        // 即使最后没有空闲周期，也要记录运行阶段结束时的连续段。
        finish_streaks();
    endfunction

    function int walking_index(logic [DATA_WIDTH-1:0] data);
        if ($isunknown(data) || !$onehot(data)) begin
            return -1;
        end
        for (int i = 0; i < DATA_WIDTH; i++) begin
            if (data[i]) return i;
        end
        return -1;
    endfunction

    function void sample_data(fifo_monitor_item t);
        bit wr_success;
        bit rd_success;
        int wr_index;
        int rd_index;

        wr_success = t.wr_en && !t.pre_full;
        rd_success = t.rd_en && !t.pre_empty;

        // 转成逐位 bit 采样前检查四态，避免 X/Z 静默变为 0。
        // 只抑制有未知数据的方向，另一方向仍可正常采样。
        if (wr_success && $isunknown(t.wr_data)) begin
            `uvm_error("COV_UNKNOWN_DATA", "Unknown data during accepted write")
            wr_success = 0;
        end
        if (rd_success && $isunknown(t.rd_data)) begin
            `uvm_error("COV_UNKNOWN_DATA", "Unknown data during accepted read")
            rd_success = 0;
        end

        data_cg.sample(wr_success, rd_success, t.wr_data, t.rd_data);

        wr_index = wr_success ? walking_index(t.wr_data) : -1;
        rd_index = rd_success ? walking_index(t.rd_data) : -1;
        walking_cg.sample(wr_index, rd_index);

        for (int i = 0; i < DATA_WIDTH; i++) begin
            data_bit_cg.sample(i, wr_success, rd_success, t.wr_data[i], t.rd_data[i]);
        end
    endfunction

    function void sample_errors(fifo_monitor_item t);
        if (t.rst === 1'b1) begin
            // 不统计复位期间的变化；已观察到的复位零值可作为起点。
            previous_wr_error = 0;
            previous_rd_error = 0;
            error_history_valid = (t.wr_error === 1'b0) &&
                                  (t.rd_error === 1'b0);
            return;
        end

        if ($isunknown({t.rst, t.wr_error, t.rd_error})) begin
            // 不把未知值转成 bit，也不跨过未知周期拼接变化。
            error_history_valid = 0;
            `uvm_error("COV_UNKNOWN_ERROR", "Unknown reset or error signal in coverage")
            return;
        end

        if (error_history_valid) begin
            error_cg.sample(
                previous_wr_error, t.wr_error,
                previous_rd_error, t.rd_error
            );
            error_sample_count++;
        end

        // 先采样，再更新上一拍的值。
        previous_wr_error = t.wr_error;
        previous_rd_error = t.rd_error;
        error_history_valid = 1;
    endfunction

    // occupancy 表示本拍操作完成后的模型队列长度
    function void write_expected(fifo_expected_item t);
        if (t.rst) begin
            return;
        end

        if (t.pre_occupancy > DEPTH || t.occupancy > DEPTH) begin
            `uvm_error(
                "COV_BAD_COUNT",
                $sformatf("Occupancy before=%0d, after=%0d exceeds DEPTH %0d",
                          t.pre_occupancy, t.occupancy, DEPTH)
            )
            return;
        end

        occupancy_cg.sample(t.occupancy);
        occupancy_sample_count++;

        // 使用同一拍的操作前后数量，不把跨复位或遗漏周期拼成变化。
        if (t.pre_occupancy == 0 && t.occupancy == 1) begin
            boundary_cg.sample(leave_empty);
            boundary_hits[leave_empty]++;
        end
        if (t.pre_occupancy == 1 && t.occupancy == 0) begin
            boundary_cg.sample(enter_empty);
            boundary_hits[enter_empty]++;
        end
        if (t.pre_occupancy == DEPTH - 1 && t.occupancy == DEPTH) begin
            boundary_cg.sample(enter_full);
            boundary_hits[enter_full]++;
        end
        if (t.pre_occupancy == DEPTH && t.occupancy == DEPTH - 1) begin
            boundary_cg.sample(leave_full);
            boundary_hits[leave_full]++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(
            "FIFO_COVERAGE",
            $sformatf(
                "samples=%0d, request=%0.2f%%, state=%0.2f%%, state_request=%0.2f%%",
                sample_count,
                fifo_cg.cp_request.get_inst_coverage(),
                fifo_cg.cp_state.get_inst_coverage(),
                fifo_cg.cx_state_request.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_OCCUPANCY_COVERAGE",
            $sformatf(
                "samples=%0d, occupancy=%0.2f%%",
                occupancy_sample_count,
                occupancy_cg.cp_occupancy.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_BOUNDARY_COVERAGE",
            $sformatf(
                "boundary=%0.2f%%, 0_to_1=%0d, 1_to_0=%0d, almost_full_to_full=%0d, full_to_almost_full=%0d",
                boundary_cg.cp_boundary.get_inst_coverage(),
                boundary_hits[leave_empty], boundary_hits[enter_empty],
                boundary_hits[enter_full], boundary_hits[leave_full]
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_ERROR_COVERAGE",
            $sformatf(
                "samples=%0d, wr_error=%0.2f%%, rd_error=%0.2f%%",
                error_sample_count,
                error_cg.cp_wr_error.get_inst_coverage(),
                error_cg.cp_rd_error.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_DATA_COVERAGE",
            $sformatf(
                "write_patterns=%0.2f%%, read_patterns=%0.2f%%",
                data_cg.cp_wr_data.get_inst_coverage(),
                data_cg.cp_rd_data.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_WALKING_COVERAGE",
            $sformatf(
                "write_positions=%0.2f%%, read_positions=%0.2f%%",
                walking_cg.cp_wr_position.get_inst_coverage(),
                walking_cg.cp_rd_position.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_BIT_COVERAGE",
            $sformatf(
                "write_bits=%0.2f%%, read_bits=%0.2f%%",
                data_bit_cg.cp_wr_bit.get_inst_coverage(),
                data_bit_cg.cp_rd_bit.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_STREAK_COVERAGE",
            $sformatf(
                "write_streak=%0.2f%%, read_streak=%0.2f%%",
                streak_cg.cp_write_streak.get_inst_coverage(),
                streak_cg.cp_read_streak.get_inst_coverage()
            ),
            UVM_LOW
        )

        `uvm_info(
            "FIFO_OUTPUT_HOLD_COVERAGE",
            $sformatf(
                "output_hold=%0.2f%%, idle=%0d, write_only=%0d, empty_read=%0d",
                output_hold_cg.cp_output_hold.get_inst_coverage(),
                hold_hits[idle_hold], hold_hits[write_only_hold],
                hold_hits[empty_read_hold]
            ),
            UVM_LOW
        )
    endfunction

endclass
