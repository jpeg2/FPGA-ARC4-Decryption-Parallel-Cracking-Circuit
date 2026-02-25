`timescale 1ps / 1ps

module tb_rtl_task3;
    timeunit 1ps;
    timeprecision 1ps;

    // Clock/reset + DUT IO
    logic CLOCK_50 = 0;
    logic [3:0] KEY = 4'b0000;
    logic [9:0] SW = 10'h155;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    // Reference arrays
    logic [7:0] ct_mem [0:255];
    byte pt_expect [0:255];

    task3 dut(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
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

    initial begin
        $readmemh("test1.memh", ct_mem);
        byte s_tmp [0:255];
        byte key_bytes [0:2];
        int j_accum;
        byte tmp_byte;
        key_bytes[0] = 8'h00;
        key_bytes[1] = 8'h01;
        key_bytes[2] = 8'h55;
        for (int i = 0; i < 256; i++) s_tmp[i] = i[7:0];
        j_accum = 0;
        for (int i = 0; i < 256; i++) begin
            j_accum = (j_accum + s_tmp[i] + key_bytes[i % 3]) % 256;
            tmp_byte = s_tmp[i];
            s_tmp[i] = s_tmp[j_accum];
            s_tmp[j_accum] = tmp_byte;
        end
        int i_idx;
        int j_idx;
        i_idx = 0;
        j_idx = 0;
        pt_expect[0] = ct_mem[0];
        for (int k = 1; k <= ct_mem[0]; k++) begin
            i_idx = (i_idx + 1) % 256;
            j_idx = (j_idx + s_tmp[i_idx]) % 256;
            tmp_byte = s_tmp[i_idx];
            s_tmp[i_idx] = s_tmp[j_idx];
            s_tmp[j_idx] = tmp_byte;
            pt_expect[k] = ct_mem[k] ^ s_tmp[(s_tmp[i_idx] + s_tmp[j_idx]) % 256];
        end
        #10;
        for (int i = 0; i <= ct_mem[0]; i++) begin
            dut.ct.altsyncram_component.m_default.altsyncram_inst.mem_data[i] = ct_mem[i];
        end

        repeat (5) @(posedge CLOCK_50);
        KEY[3] = 1'b1;

        bit done = 0;
        repeat (8000) begin
            @(posedge CLOCK_50);
            if (dut.a4.rdy) begin
                done = 1'b1;
                break;
            end
        end
        if (!done) $fatal("task3 did not finish arc4 run");

        for (int i = 0; i <= pt_expect[0]; i++) begin
            if (dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] !== pt_expect[i]) begin
                $fatal("PT mismatch at %0d: expected %0d got %0d", i, pt_expect[i], dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
            end
        end

        $display("tb_rtl_task3 completed successfully");
        $finish;
    end
endmodule: tb_rtl_task3
