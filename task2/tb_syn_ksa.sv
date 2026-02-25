`timescale 1ps / 1ps

module tb_syn_ksa;
    timeunit 1ps;
    timeprecision 1ps;

    logic clk = 0;
    logic rst_n = 0;
    logic en = 0;
    logic rdy;
    logic [7:0] addr;
    logic [7:0] rddata;
    logic [7:0] wrdata;
    logic wren;

    byte s_expect [0:255];

    ksa dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(24'h000155),
            .addr(addr), .rddata(rddata), .wrdata(wrdata), .wren(wren));
    s_mem s(.address(addr), .clock(clk), .data(wrdata), .wren(wren), .q(rddata));

    initial begin
        clk = 1'b0;
        forever begin
            #5000;
            clk = ~clk;
        end
    end

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
        #10;
        for (int i = 0; i < 256; i++) begin
            s.altsyncram_component.m_default.altsyncram_inst.mem_data[i] = i[7:0];
            s.\altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[i] = i[7:0];
        end

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        bit start_ready = 0;
        repeat (1200) begin
            @(posedge clk);
            if (rdy) begin
                start_ready = 1'b1;
                break;
            end
        end
        if (!start_ready) $fatal("ksa never asserted rdy after reset (post-synth)");
        en = 1'b1;
        @(posedge clk);
        en = 1'b0;

        int write_count = 0;
        bit done = 0;
        repeat (1200) begin
            @(posedge clk);
            if (wren) write_count++;
            if (rdy) begin
                done = 1'b1;
                break;
            end
        end
        if (!done) $fatal("ksa never asserted rdy after start (post-synth)");
        if (write_count != 512) $fatal("expected 512 writes, saw %0d", write_count);

        for (int i = 0; i < 256; i++) begin
            if (s.\altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[i] !== s_expect[i]) begin
                $fatal("S mismatch at %0d: expected %0d got %0d", i, s_expect[i], s.\altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[i]);
            end
        end

        $display("tb_syn_ksa completed successfully");
        $finish;
    end
endmodule: tb_syn_ksa
