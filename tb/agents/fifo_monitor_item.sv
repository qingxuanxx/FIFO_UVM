class fifo_monitor_item extends uvm_sequence_item;

    // 注册到 uvm factory
    `uvm_object_utils(fifo_monitor_item)

    bit rst;

    // 上升沿之前的请求
    bit wr_en;
    bit rd_en;
    bit [7:0] wr_data;

    // dut 处理之前的状态
    bit pre_full;
    bit pre_empty;

    // dut 处理之后的结果
    bit [7:0] rd_data;
    bit wr_error;
    bit rd_error;

    // dut 处理之后的状态
    bit post_full;
    bit post_empty;

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