`timescale 1ps / 1ps

module tb_rtl_task2;
    timeunit 1ps;
    timeprecision 1ps;

    // Clock/reset + DUT IO
    logic CLOCK_50 = 0;
    logic [3:0] KEY = 4'b0000;
    logic [9:0] SW = 10'h155;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    task2 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
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

    byte s_expect [0:255];

    initial begin

        byte key_bytes [0:2];
        int j_accum;
        byte tmp_byte;
        key_bytes[0] = 8'h00;
        key_bytes[1] = 8'h01;
        key_bytes[2] = 8'h55;
        for (int i = 0; i < 256; i++) s_expect[i] = i[7:0];
        j_accum = 0;
        for (int i = 0; i < 256; i++) begin
            j_accum = (j_accum + s_expect[i] + key_bytes[i % 3]) % 256;
            tmp_byte = s_expect[i];
            s_expect[i] = s_expect[j_accum];
            s_expect[j_accum] = tmp_byte;
        end

        repeat (5) @(posedge CLOCK_50);
        KEY[3] = 1'b1;

        bit done = 0;
        repeat (4000) begin
            @(posedge CLOCK_50);
            if (dut.rdy_k) begin
                done = 1'b1;
                break;
            end
        end
        if (!done) $fatal("task2 never signaled KSA completion");

        for (int i = 0; i < 256; i++) begin
            if (dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] !== s_expect[i]) begin
                $fatal("S mismatch at %0d: expected %0d got %0d", i, s_expect[i], dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
            end
        end

        repeat (3) begin
            @(posedge CLOCK_50);
            if (dut.wren_k || dut.wren_s) $fatal("write enable asserted after completion");
        end

        $display("tb_rtl_task2 completed successfully");
        $finish;
    end
endmodule: tb_rtl_task2
