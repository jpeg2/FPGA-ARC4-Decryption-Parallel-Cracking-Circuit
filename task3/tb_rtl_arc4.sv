`timescale 1ps / 1ps

module tb_rtl_arc4;
    timeunit 1ps;
    timeprecision 1ps;

    // Clock/reset + handshake
    logic clk = 0;
    logic rst_n = 0;
    logic en = 0;
    logic rdy;

    // ARC4 interfaces
    logic [23:0] key = 24'h000155;
    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;
    logic [7:0] pt_addr;
    logic [7:0] pt_rddata = 8'h00;
    logic [7:0] pt_wrdata;
    logic pt_wren;

    // Memory models
    logic [7:0] ct_mem [0:255];
    logic [7:0] pt_capture [0:255];

    // Expected plaintext
    byte pt_expect [0:255];

    arc4 dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(key),
             .ct_addr(ct_addr), .ct_rddata(ct_rddata),
             .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));

    initial begin
        clk = 1'b0;
        forever begin
            #5000;
            clk = ~clk;
        end
    end

    assign ct_rddata = ct_mem[ct_addr];
    always_ff @(posedge clk) if (pt_wren) pt_capture[pt_addr] <= pt_wrdata;

    initial begin
        $readmemh("test1.memh", ct_mem);
        byte s_tmp [0:255];
        byte key_bytes [0:2];
        int j_accum;
        byte tmp_byte;
        key_bytes[0] = key[23:16];
        key_bytes[1] = key[15:8];
        key_bytes[2] = key[7:0];
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

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        wait(rdy==1);
        en = 1'b1;
        @(posedge clk);
        en = 1'b0;

        bit done = 0;
        repeat (6000) begin
            @(posedge clk);
            if (rdy) begin
                done = 1'b1;
                break;
            end
        end
        if (!done) $fatal("arc4 did not finish");

        for (int i = 0; i <= pt_expect[0]; i++) begin
            if (pt_capture[i] !== pt_expect[i]) begin
                $fatal("PT mismatch at %0d: expected %0d got %0d", i, pt_expect[i], pt_capture[i]);
            end
        end

        $display("tb_rtl_arc4 completed successfully");
        $finish;
    end
endmodule: tb_rtl_arc4
