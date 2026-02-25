`timescale 1ps / 1ps

module tb_syn_task1;
    timeunit 1ps;
    timeprecision 1ps;

    logic CLOCK_50 = 0;
    logic [3:0] KEY = 4'b0000;
    logic [9:0] SW = 10'b0;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;
    logic altera_reserved_tms = 1'b0;
    logic altera_reserved_tck = 1'b0;
    logic altera_reserved_tdi = 1'b0;
    logic altera_reserved_tdo;

    task1 dut(
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR),
        .altera_reserved_tms(altera_reserved_tms),
        .altera_reserved_tck(altera_reserved_tck),
        .altera_reserved_tdi(altera_reserved_tdi),
        .altera_reserved_tdo(altera_reserved_tdo)
    );

    initial begin
        CLOCK_50 = 1'b0;
        forever begin
            #5000;
            CLOCK_50 = ~CLOCK_50;
        end
    end

    initial begin
        repeat (5) @(posedge CLOCK_50);
        KEY[3] = 1'b1;

        repeat (1400) @(posedge CLOCK_50);

        for (int idx = 0; idx < 256; idx++) begin
            if (dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[idx] !== idx[7:0]) begin
                $fatal("expected %0d got %0d",
                       idx[7:0],
                       dut.\s|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[idx]);
            end
        end

        $display("tb_syn_task1 completed successfully");
        $finish;
    end
endmodule: tb_syn_task1
