// 编译时通过 +define+FIFO_WIDTH=<值> 和 +define+FIFO_DEPTH=<值> 选择配置。
`ifndef FIFO_WIDTH
    `define FIFO_WIDTH 8
`endif

`ifndef FIFO_DEPTH
    `define FIFO_DEPTH 16
`endif

package fifo_config_pkg;
    localparam int DATA_WIDTH = `FIFO_WIDTH;
    localparam int DEPTH = `FIFO_DEPTH;
endpackage
