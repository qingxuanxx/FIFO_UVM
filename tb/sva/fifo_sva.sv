`ifndef FIFO_SVA_SV
`define FIFO_SVA_SV

// 独立检查模块：由 UVM top 实例化，不修改 DUT。
module fifo_sva #(
    parameter int width = 8,
    parameter int depth = 16,
    localparam int addr_width = $clog2(depth),
    localparam int ptr_width = addr_width + 1
) (
    input logic clk,
    input logic rst,
    input logic wr_en,
    input logic rd_en,
    input logic [width-1:0] rd_data,
    input logic full,
    input logic empty,
    input logic wr_error,
    input logic rd_error,
    input logic [ptr_width-1:0] wr_ptr,
    input logic [ptr_width-1:0] rd_ptr
);
    timeunit 1ns;
    timeprecision 1ps;

    import uvm_pkg::*;

    int unsigned failures = 0;
    int unsigned reset_checks = 0;
    int unsigned wr_steps = 0;
    int unsigned rd_steps = 0;
    int unsigned wr_holds = 0;
    int unsigned rd_holds = 0;
    int unsigned output_holds = 0;
    int unsigned full_writes = 0;
    int unsigned empty_reads = 0;
    int unsigned wr_address_wraps = 0;
    int unsigned rd_address_wraps = 0;
    int unsigned wr_pointer_wraps = 0;
    int unsigned rd_pointer_wraps = 0;

    function void report_failure(string rule);
        failures++;
        uvm_report_error("FIFO_SVA", $sformatf("%m: %s failed", rule), UVM_NONE);
    endfunction

    initial begin
        $display("FIFO_SVA_ENABLED: width=%0d, depth=%0d", width, depth);
    end

    // 复位边沿与复位期间的时钟沿：等待一个仿真精度单位，
    // 让 DUT 的 NBA 赋值和空满组合逻辑稳定后，再求值。
    // 本模块精度为 1 ps；检查发生在触发事件后的 1 ps。
    always @(posedge rst or posedge clk) begin
        if (rst === 1'b1) begin
            reset_checks++;
            #1ps;
            ap_reset_values: assert (
                (wr_ptr === '0) && (rd_ptr === '0) &&
                (rd_data === '0) && (wr_error === 1'b0) &&
                (rd_error === 1'b0) && (full === 1'b0) &&
                (empty === 1'b1)
            ) else report_failure("ap_reset_values");
        end
    end

    ap_reset_known: assert property (
        @(posedge clk) !$isunknown(rst)
    ) else report_failure("ap_reset_known");

    // 并发断言采样的是上升沿更新前的值。
    // |=> 在下一上升沿检查本拍更新，$past 仅在该后件中使用。
    ap_signals_known: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !$isunknown({wr_en, rd_en, wr_ptr, rd_ptr, rd_data,
                     full, empty, wr_error, rd_error})
    ) else report_failure("ap_signals_known");

    ap_not_full_and_empty: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(full && empty)
    ) else report_failure("ap_not_full_and_empty");

    ap_empty_matches_pointers: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        empty === (wr_ptr == rd_ptr)
    ) else report_failure("ap_empty_matches_pointers");

    ap_full_matches_pointers: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        full === ((wr_ptr[ptr_width-1] != rd_ptr[ptr_width-1]) &&
                  (wr_ptr[addr_width-1:0] == rd_ptr[addr_width-1:0]))
    ) else report_failure("ap_full_matches_pointers");

    ap_wr_ptr_increment: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && !full) |=> (wr_ptr === ($past(wr_ptr) + ptr_width'(1)))
    ) else report_failure("ap_wr_ptr_increment");

    ap_wr_ptr_hold: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(wr_en && !full) |=> (wr_ptr === $past(wr_ptr))
    ) else report_failure("ap_wr_ptr_hold");

    ap_rd_ptr_increment: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && !empty) |=> (rd_ptr === ($past(rd_ptr) + ptr_width'(1)))
    ) else report_failure("ap_rd_ptr_increment");

    ap_rd_ptr_hold: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(rd_en && !empty) |=> (rd_ptr === $past(rd_ptr))
    ) else report_failure("ap_rd_ptr_hold");

    ap_read_output_hold: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(rd_en && !empty) |=> (rd_data === $past(rd_data))
    ) else report_failure("ap_read_output_hold");

    ap_write_error_timing: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        1'b1 |=> (wr_error === $past(wr_en && full))
    ) else report_failure("ap_write_error_timing");

    ap_read_error_timing: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        1'b1 |=> (rd_error === $past(rd_en && empty))
    ) else report_failure("ap_read_error_timing");

    ap_wr_address_wrap: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && !full && wr_ptr[addr_width-1:0] == addr_width'(depth-1))
        |=> ((wr_ptr[addr_width-1:0] === '0) &&
             (wr_ptr[ptr_width-1] === ~$past(wr_ptr[ptr_width-1])))
    ) else report_failure("ap_wr_address_wrap");

    ap_rd_address_wrap: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && !empty && rd_ptr[addr_width-1:0] == addr_width'(depth-1))
        |=> ((rd_ptr[addr_width-1:0] === '0) &&
             (rd_ptr[ptr_width-1] === ~$past(rd_ptr[ptr_width-1])))
    ) else report_failure("ap_rd_address_wrap");

    ap_wr_pointer_wrap: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && !full && (&wr_ptr)) |=> (wr_ptr === '0)
    ) else report_failure("ap_wr_pointer_wrap");

    ap_rd_pointer_wrap: assert property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && !empty && (&rd_ptr)) |=> (rd_ptr === '0)
    ) else report_failure("ap_rd_pointer_wrap");

    // 使用实际序列匹配统计触发，避免把蕴含式的空成功算成覆盖。
    cp_wr_step: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && !full) ##1 (wr_ptr === ($past(wr_ptr) + ptr_width'(1)))
    ) wr_steps++;
    cp_rd_step: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && !empty) ##1 (rd_ptr === ($past(rd_ptr) + ptr_width'(1)))
    ) rd_steps++;
    cp_wr_hold: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(wr_en && !full) ##1 (wr_ptr === $past(wr_ptr))
    ) wr_holds++;
    cp_rd_hold: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(rd_en && !empty) ##1 (rd_ptr === $past(rd_ptr))
    ) rd_holds++;
    cp_output_hold: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        !(rd_en && !empty) ##1 (rd_data === $past(rd_data))
    ) output_holds++;
    cp_full_write: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && full) ##1 (wr_error === 1'b1)
    ) full_writes++;
    cp_empty_read: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && empty) ##1 (rd_error === 1'b1)
    ) empty_reads++;
    cp_wr_address_wrap: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && !full && wr_ptr[addr_width-1:0] == addr_width'(depth-1))
        ##1 ((wr_ptr[addr_width-1:0] === '0) &&
             (wr_ptr[ptr_width-1] === ~$past(wr_ptr[ptr_width-1])))
    ) wr_address_wraps++;
    cp_rd_address_wrap: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && !empty && rd_ptr[addr_width-1:0] == addr_width'(depth-1))
        ##1 ((rd_ptr[addr_width-1:0] === '0) &&
             (rd_ptr[ptr_width-1] === ~$past(rd_ptr[ptr_width-1])))
    ) rd_address_wraps++;
    cp_wr_pointer_wrap: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (wr_en && !full && (&wr_ptr)) ##1 (wr_ptr === '0)
    ) wr_pointer_wraps++;
    cp_rd_pointer_wrap: cover property (
        @(posedge clk) disable iff (rst !== 1'b0)
        (rd_en && !empty && (&rd_ptr)) ##1 (rd_ptr === '0)
    ) rd_pointer_wraps++;

    final begin
        $display("FIFO_SVA_SUMMARY: failures=%0d, reset_checks=%0d", failures, reset_checks);
        $display("FIFO_SVA_ACTIVITY: wr_steps=%0d, rd_steps=%0d, wr_holds=%0d, rd_holds=%0d, output_holds=%0d, full_writes=%0d, empty_reads=%0d",
                 wr_steps, rd_steps, wr_holds, rd_holds, output_holds, full_writes, empty_reads);
        $display("FIFO_SVA_WRAP: wr_address=%0d, rd_address=%0d, wr_pointer=%0d, rd_pointer=%0d",
                 wr_address_wraps, rd_address_wraps, wr_pointer_wraps, rd_pointer_wraps);
    end
endmodule

`endif
