class fifo_env extends uvm_env;

    `uvm_component_utils(fifo_env)

    fifo_agent agent;
    fifo_scoreboard scoreboard;
    fifo_coverage coverage;

    function new(string name = "fifo_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 创建agent和scoreboard
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = fifo_agent::type_id::create("agent", this);
        scoreboard = fifo_scoreboard::type_id::create("scoreboard", this);
        coverage = fifo_coverage::type_id::create("coverage", this);

    endfunction

    // 将agent的采样输出连接到scoreboard/coverage
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // agent 和 scoreboard 之间的连接
        agent.analysis_port.connect(scoreboard.analysis_export);

        agent.analysis_port.connect(coverage.analysis_export);

        scoreboard.expected_port.connect(coverage.expected_export);

    endfunction

endclass
