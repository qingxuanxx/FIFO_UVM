// 时钟、复位和 DUT 实例放进 fifo_tb_top.sv

`include "uvm_macros.svh"

module fifo_tb_top;

    timeunit 1ns;
    timeprecision 1ps;

    // 导入 UVM 包：uvm_pkg 包含 UVM 提供的类。导入后，下面才能使用 uvm_config_db
    import uvm_pkg::*;

    `include "agents/fifo_item.sv"
    `include "agents/fifo_sequencer.sv"
    `include "agents/fifo_driver.sv"
    `include "agents/fifo_agent.sv"
    `include "seq/fifo_sequence.sv"
    `include "tests/fifo_test.sv"

    parameter int width = 8;
    parameter int depth = 16;

    // 1. 产生时钟：周期为10ns
    logic clk = 1'b0;
    always #5ns clk = ~clk;

    // 2. 实例化 interface
    fifo_if #(
        .width(width)
    ) vif (
        .clk(clk)
    );

    // 3. 实例化 dut，并且连接 interface 中的信号
    fifo #(
        .width(width),
        .depth(depth)
    ) dut (
        .clk(clk),
        .rst(vif.rst),
        .wr_en(vif.wr_en),
        .wr_data(vif.wr_data),
        .rd_en(vif.rd_en),
        .rd_data(vif.rd_data),
        .full(vif.full),
        .empty(vif.empty),
        .wr_error(vif.wr_error), 
        .rd_error(vif.rd_error)
    );

    // 4. 设置初始输入，并且产生复位
    initial begin
        // 初始化
        vif.rst = 1'b1;
        vif.wr_en = 1'b0;
        vif.rd_en = 1'b0;
        vif.wr_data = '0;

        repeat (2) @(negedge clk);
        vif.rst = 1'b0;

        // repeat (2) @(negedge clk);
        // $finish;
    end

    // 5. 打印信号
    initial begin
        $monitor(
            "time = %0t, clk = %b, rst = %b, wr_en = %b, rd_en = %b, wr_data = %h, rd_data = %h, wr_error = %b, rd_error = %b",
            $time, clk, vif.rst, vif.wr_en, vif.rd_en,
            vif.wr_data, vif.rd_data, vif.wr_error, vif.rd_error
        );
    end

    // 6. config_db::set()
    initial begin
        // 将接口实例 vif 存入 UVM 配置数据库，供 test 下的 driver、monitor 等组件获取
        uvm_config_db #(virtual fifo_if #(width))::set(
            null,
            "uvm_test_top*",  // 配置适用于 test 本身及其下面的组件，区别于 “uvm_test_top.*”
            "vif",  // 给这项配置起的名字
            vif  // 要存入的实际值，也是在 top 中实例化的 interface 名字
        );

        // 创建并启动 fifo_test
        run_test("fifo_test");

    end


endmodule
