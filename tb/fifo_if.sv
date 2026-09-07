// 接口信号放进 fifo_if.sv
// interface 是一组信号的集合，以后 driver 和 monitor 通过这组信号访问 DUT
interface fifo_if #(
    parameter int width = 8
) (
    input logic clk
);

    logic rst;

    logic wr_en;
    logic [width-1:0] wr_data;

    logic rd_en;
    logic [width-1:0] rd_data;

    logic full;
    logic empty;

    logic wr_error;
    logic rd_error;

    // driver 在下降沿驱动读写请求
    clocking drv_cb @(negedge clk);
        // 避免不同进程在同一个时间点操作信号时产生先后顺序上的歧义
        default input #1step output #0;

        // driver 要知道“现在是否正在复位”，所以要读取 rst
        input rst;
        // driver 负责决定是否写、写什么、是否读，
        // 所以要驱动 wr_en、wr_data、rd_en
        output wr_en;
        output wr_data;
        output rd_en;
    endclocking

    // monitor 在上升沿观察请求和执行结果
    clocking mon_cb @(posedge clk);
        // 即使在 monitor 中也写上 output #0，因为没有声明输出信号，也没有实际用途
        default input #1step;

        // 上升沿之前：dut 即将处理的请求和状态
        input rst;
        input wr_en;  // 使用默认的 #1step
        input wr_data;
        input rd_en;

        input pre_full = full;
        input pre_empty = empty;

        // 上升沿之后：dut 处理完之后的结果
        input #0 rd_data;  // 单独指定 #0
        input #0 wr_error;
        input #0 rd_error;

        input #0 post_full = full;
        input #0 post_empty = empty;

    endclocking

endinterface
