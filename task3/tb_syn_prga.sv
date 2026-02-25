`timescale 1ps / 1ps

module tb_syn_prga;
    timeunit 1ps;
    timeprecision 1ps;

    logic clk = 0;
    logic rst_n = 0;
    logic en = 0;
    logic rdy;

    logic [7:0] s_addr;
    logic [7:0] s_rddata;
    logic [7:0] s_wrdata;
    logic s_wren;

    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;
    logic [7:0] pt_addr;
    logic [7:0] pt_rddata;
    logic [7:0] pt_wrdata;
    logic pt_wren;

    logic [7:0] ct_mem [0:255];
    logic [7:0] pt_capture [0:255];

    byte s_seed   [0:255];
    byte pt_expect[0:255];

    prga dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(24'h000155),
             .s_addr(s_addr), .s_rddata(s_rddata), .s_wrdata(s_wrdata), .s_wren(s_wren),
             .ct_addr(ct_addr), .ct_rddata(ct_rddata),
             .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));
    s_mem s(.address(s_addr), .clock(clk), .data(s_wrdata), .wren(s_wren), .q(s_rddata));

    initial begin
        clk = 1'b0;
        forever begin
            #5000;
            clk = ~clk;
        end
    end

    assign pt_rddata = 8'h00;
    assign ct_rddata = ct_mem[ct_addr];

    always_ff @(posedge clk) if (pt_wren) pt_capture[pt_addr] <= pt_wrdata;

    initial begin
        $readmemh("test1.memh", ct_mem);
        byte key_bytes [0:2];
        int j_accum;
        byte tmp_byte;
        key_bytes[0] = 8'h00;
        key_bytes[1] = 8'h01;
        key_bytes[2] = 8'h55;
        for (int i = 0; i < 256; i++) s_seed[i] = i[7:0];
        j_accum = 0;
        for (int i = 0; i < 256; i++) begin
            j_accum = (j_accum + s_seed[i] + key_bytes[i % 3]) % 256;
            tmp_byte = s_seed[i];
            s_seed[i] = s_seed[j_accum];
            s_seed[j_accum] = tmp_byte;
        end
        int i_idx;
        int j_idx;
        i_idx = 0;
        j_idx = 0;
        pt_expect[0] = ct_mem[0];
        for (int k = 1; k <= ct_mem[0]; k++) begin
            i_idx = (i_idx + 1) % 256;
            j_idx = (j_idx + s_seed[i_idx]) % 256;
            tmp_byte = s_seed[i_idx];
            s_seed[i_idx] = s_seed[j_idx];
            s_seed[j_idx] = tmp_byte;
            pt_expect[k] = ct_mem[k] ^ s_seed[(s_seed[i_idx] + s_seed[j_idx]) % 256];
        end

        #10;
        for (int i = 0; i < 256; i++) begin
            s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] = s_seed[i];
            s.\altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[i] = s_seed[i];
        end

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        en = 1'b1;
        @(posedge clk);
        en = 1'b0;

        bit done = 0;
        repeat (4000) begin
            @(posedge clk);
            if (rdy) begin
                done = 1'b1;
                break;
            end
        end
        if (!done) $fatal("prga did not finish (post-synth)");

        for (int i = 0; i <= pt_expect[0]; i++) begin
            if (pt_capture[i] !== pt_expect[i]) begin
                $fatal("PT mismatch at %0d: expected %0d got %0d", i, pt_expect[i], pt_capture[i]);
            end
        end

        $display("tb_syn_prga completed successfully");
        $finish;
    end
endmodule: tb_syn_prga
