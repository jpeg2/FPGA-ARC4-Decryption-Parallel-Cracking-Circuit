`timescale 1ps / 1ps

module tb_rtl_init;
    timeunit 1ps;
    timeprecision 1ps;

    // signals
    logic clk = 0;
    logic rst_n = 0;
    logic en = 0;
    logic rdy;
    logic [7:0] addr;
    logic [7:0] wrdata;
    logic wren;

    init dut(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .addr(addr), .wrdata(wrdata), .wren(wren));

    initial begin
        clk = 1'b0;
        forever begin
            #5000;
            clk = ~clk;
        end
    end

    int write_count = 0;
    bit done_flag = 0;

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        wait (rdy == 1);

        en = 1'b1;
        @(posedge clk);
        en = 1'b0;

        repeat (2000) begin
            @(posedge clk);
            if (wren) begin
                if (addr !== wrdata) $fatal("addr=%0d wrdata=%0d", addr, wrdata);
                if (addr !== write_count[7:0]) $fatal("write_count=%0d addr=%0d", write_count, addr);
                write_count++;
            end
            if (rdy) begin
                done_flag = 1'b1;
                break;
            end
        end

        if (!done_flag) $fatal("no rdy");
        if (write_count != 256) $fatal("writes=%0d", write_count);

        repeat (3) begin
            @(posedge clk);
            if (wren) $fatal("wren asserted after completion");
        end

        $display("tb_rtl_init completed successfully");
        $finish;
    end
endmodule: tb_rtl_init
