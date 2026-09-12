class fifo_driver extends uvm_driver #(fifo_item);

    // 注册到 uvm factory
    `uvm_component_utils(fifo_driver)

    // 通过 config_db 获取 interface
    virtual fifo_if #(8) vif;

    // 构造函数
    function new(string name = "fifo_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 获取 interface
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual fifo_if #(8))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "fifo_driver cannot get FIFO interface")
        end

    endfunction

    // 从 sequencer 获取 item，并且驱动 driver
    task run_phase(uvm_phase phase);

        fifo_item item;

        // 等待初始复位释放
        wait (vif.rst === 1'b0);
        // 用 === 而不是 == 是因为SystemVerilog信号可能存在四种状态：0、1、X、Z
        // 明确要求 rst 必须真正等于 0，如果它是 X 或 Z，driver 会继续等待

        forever begin

            // 等待并获取 sequencer 产生的 item
            seq_item_port.get_next_item(item);

            // 在下降沿驱动 DUT 输入
            @(vif.drv_cb);

            // 将 item 中的请求驱动到 interface
            vif.drv_cb.wr_en <= item.wr_en;
            vif.drv_cb.wr_data <= item.wr_data;
            vif.drv_cb.rd_en <= item.rd_en;

            // 打印 driver 实际收到的 item
            `uvm_info("FIFO_DRIVER", item.convert2string(), UVM_LOW)

            // 等待下一个下降沿，让请求保持一个完整周期
            @(vif.drv_cb);

            // 这一笔请求结束，置0
            vif.drv_cb.wr_en <= 1'b0;
            vif.drv_cb.wr_data <= '0;
            vif.drv_cb.rd_en <= 1'b0;

            // 告诉 sequencer：这个 item 已经处理完成
            seq_item_port.item_done();

        end

    endtask
endclass