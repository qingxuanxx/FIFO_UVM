class fifo_expected_item extends uvm_object;

    // fifo_monitor_item   = DUT 的实际结果
    // fifo_expected_item  = reference model 的预期结果

    `uvm_object_utils(fifo_expected_item)

    bit rst;

    // fifo_expected_item 只存放“预期结果（标准答案）”，不存放“输入激励”
    // wr_en, rd_en, wr_data 是输入激励，已经由 monitor_item 携带并传给了参考模型
    // 且，在 Scoreboard 比对时，只需比对 DUT 的“输出”，无需比对“输入”

    bit pre_full;
    bit pre_empty;

    bit [7:0] rd_data;
    bit wr_error;
    bit rd_error;

    bit post_full;
    bit post_empty;

    int unsigned occupancy;  // 当前 FIFO 里存了多少个数据

    // 构造函数
    function new(string name = "fifo_expected_item");
        super.new(name);
    endfunction

    // 将采样结果转换成字符串，方便打印
    function string convert2string();

        return $sformatf(
            "pre_full=%b, pre_empty=%b, rd_data=%h, wr_error=%b, rd_error=%b, post_full=%b, post_empty=%b, occupancy=%0d",
            pre_full, pre_empty,
            rd_data, wr_error, rd_error,
            post_full, post_empty, occupancy
        );

    endfunction

endclass
