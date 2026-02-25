`timescale 1ps / 1ps

module tb_rtl_task1;
    timeunit 1ps;
    timeprecision 1ps;

    logic CLOCK_50 = 0;
    logic [3:0] KEY = 4'b0000;
    logic [9:0] SW = 10'b0;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    task1 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
              .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
              .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
              .LEDR(LEDR));

    initial begin
        CLOCK_50 = 1'b0;
        forever begin
            #5000;
            CLOCK_50 = ~CLOCK_50;
        end
    end

    bit done_flag = 0;

    initial begin
        repeat (5) @(posedge CLOCK_50);
        KEY[3] = 1'b1;

        repeat (1200) begin
            @(posedge CLOCK_50);
            if (dut.i.rdy) begin
                done_flag = 1'b1;
                break;
            end
        end
        if (!done_flag) $fatal("init did not assert rdy");

        for (int idx = 0; idx < 256; idx++) begin
            if (dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[idx] !== idx[7:0]) begin
                $fatal("expected %0d got %0d",
                       idx[7:0],
                       dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[idx]);
            end
        end

        repeat (3) begin
            @(posedge CLOCK_50);
            if (dut.wren) $fatal("wren asserted after init completion");
        end

        $display("tb_rtl_task1 completed successfully");
        $finish;
    end
endmodule: tb_rtl_task1
