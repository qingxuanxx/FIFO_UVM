// 一个 fifo_item 描述一个时钟周期的读写请求
// 例如：wr_en=1，rd_en=0，wr_data=A5
// 表示“请求写入 A5，不读取”
class fifo_item extends uvm_sequence_item;

    // 注册到 uvm factory
    `uvm_object_utils(fifo_item);

    // 一拍的读写请求
    rand bit wr_en;
    rand bit rd_en;
    rand bit [7:0] wr_data;

    // 构造函数，object 没有 parent
    function new (string name = "fifo_item");
        super.new(name);
    endfunction

    // 将请求内容转换为字符串
    function string convert2string();
        return $sformatf(
            "wr_en = %b, rd_en = %b, wr_data = %h", 
            wr_en, rd_en, wr_data
        );
    endfunction

endclass