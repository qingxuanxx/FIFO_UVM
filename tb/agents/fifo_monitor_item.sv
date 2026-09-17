class fifo_monitor_item extends uvm_sequence_item;

    // 注册到 uvm factory
    `uvm_object_utils(fifo_monitor_item)

    logic rst;

    // 上升沿之前的请求
    logic wr_en;
    logic rd_en;
    logic [7:0] wr_data;

    // dut 处理之前的状态
    logic pre_full;
    logic pre_empty;

    // dut 处理之后的结果
    logic [7:0] rd_data;
    logic wr_error;
    logic rd_error;

    // dut 处理之后的状态
    logic post_full;
    logic post_empty;

    // 激励（输入）用二态，观测（输出）用四态
    // 只改 fifo_monitor_item，是因为只有它需要忠实地“看清”DUT 实际输出的所有状态（包括错误状态）
    // 对于 Driver 发送的激励对象（fifo_item）和参考模型的预期结果（expected_item）
    // 使用 bit，因为它们是纯逻辑数据，只有确定的 0 和 1
    // 对于 Monitor 采样的实际结果（fifo_monitor_item），必须使用 logic
    // 因为 DUT 在出现复位缺失、总线冲突等异常时，可能会输出 X 或 Z
    // 如果用 bit，X/Z 会被静默转换为 0，从而在 Scoreboard 比对时掩盖真实的硬件错误
    // 使用 logic 配合 !== 四态比较，才能有效捕捉这些不定态，避免假 PASS

    // 构造函数
    function new(string name = "fifo_monitor_item");
        super.new(name);
    endfunction

    // 将采样结果转换成字符串，方便 monitor 打印
    function string convert2string();

        return $sformatf(
            "rst=%b, wr_en=%b, rd_en=%b, wr_data=%h, pre_full=%b, pre_empty=%b, rd_data=%h, wr_error=%b, rd_error=%b, post_full=%b, post_empty=%b", 
            rst, wr_en, rd_en, wr_data, 
            pre_full, pre_empty, 
            rd_data, wr_error, rd_error, 
            post_full, post_empty
        );

    endfunction

endclass