`timescale 1ps/1ps

module tb_syn_crack();

    logic clk;
    logic rst_n;
    logic en;
    logic rdy;
    logic key_valid;
    logic [23:0] key;
    logic [7:0]  ct_addr, ct_rddata;

    // Using doublecrack as the DUT, however testing each crack device contained within individually
    doublecrack DUT(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(key), .key_valid(key_valid), .ct_addr (ct_addr), .ct_rddata(ct_rddata));

    always #5 clk = ~clk;

    logic [7:0] ct_mem_array [0:255];

    initial begin
        #1;
        forever begin
            ct_rddata = ct_mem_array[ct_addr];
            #10;
        end
    end

    // Working reference solution, used to verify the correct test results
    task pseudocode_arc(input logic [23:0] key24, output logic [7:0]  pt_out [0:255]);
        logic [7:0] S[0:255];
        logic [7:0] KB[0:2];
        logic [7:0] temp, L, pad;
        integer x, y, z;

        KB[0] = key24[23:16];
        KB[1] = key24[15:8];
        KB[2] = key24[7:0];

        for (x = 0; x < 256; x++) S[x] = x;

        y = 0;
        for (x = 0; x < 256; x++) begin
            y = (y + S[x] + KB[x % 3]) % 256;
            temp = S[x];
            S[x] = S[y];
            S[y] = temp;
        end

        x = 0;
        y = 0;

        L = ct_mem_array[0];
        pt_out[0] = L;

        for (z = 1; z < L; z++) begin
            x = (x + 1) % 256;
            y = (y + S[x]) % 256;

            temp = S[x];
            S[x] = S[y];
            S[y] = temp;

            pad = S[(S[x] + S[y]) % 256];
            pt_out[z] = pad ^ ct_mem_array[z];
        end
    endtask

    logic [23:0] answer_key;
    logic [7:0]  pt_ans[0:255];
    logic valid_answer;
    logic [23:0] start_addr;

    // Working reference solution, used to verify the correct test results
    task pseudocode_crack();
        logic readable;
        logic [7:0] tmp[0:255];
        logic [7:0] L, c;
        integer i;

        answer_key   = 24'hDEADFF;
        valid_answer = 0;

        for (logic [23:0] k = start_addr; k <= 24'hFFFFFF; k = k + 24'd2) begin
            pseudocode_arc(k, tmp);

            readable = 1;
            L = tmp[0];

            for (i = 1; i < L; i++) begin
                c = tmp[i];
                if (c < 8'h20 || c > 8'h7E) begin
                    readable = 0;
                    break;
                end
            end

            if (readable) begin
                answer_key   = k;
                valid_answer = 1;
                for (i = 0; i < L; i++) pt_ans[i] = tmp[i];
                break;
            end
        end
    endtask

    integer idx;
    logic err;

    task compare_output();
        // Key match
        if (key != answer_key) begin
            err = 1;
            $display("ERROR: key mismatch: expected=%h actual=%h", answer_key, key);
        end

        for (idx = 0; idx < pt_ans[0]; idx++) begin
            if (DUT.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[idx] != pt_ans[idx]) begin
                $display("Mismatch at pt[%0d]: expected=%h actual=%h",
                         idx,
                         pt_ans[idx],
                         DUT.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[idx]);
                err = 1;
            end
        end
    endtask

    // Test Sequence
    initial begin
        clk = 0;

        // TEST 1: start at 0
        $display("TEST START_ADDR = 0");
        start_addr = 24'd0;
        err = 0;
        rst_n = 0;
        en    = 0;

        $readmemh("../task3/test1.memh", ct_mem_array);

        #1;
        pseudocode_crack();

        #10 rst_n = 1;

        if (rdy != 1) begin
            $display("ERROR: rdy should be 1 after reset");
            $stop;
        end

        #10 en = 1;
        #10 en = 0;

        wait (rdy == 1);

        compare_output();

        if (err) $display("TEST FAILED (start=0)");
        else $display("TEST PASSED (start=0)");

        // TEST 2: start at 1
        #20;
        $display("TEST START_ADDR = 1");
        start_addr = 24'd1;
        err = 0;
        rst_n = 0;
        en    = 0;

        $readmemh("../task3/test1.memh", ct_mem_array);

        #1;
        pseudocode_crack();

        #10 rst_n = 1;

        if (rdy != 1) begin
            $display("ERROR: rdy should be 1 after reset");
            $stop;
        end

        #10 en = 1;
        #10 en = 0;

        wait (rdy == 1);

        compare_output();

        if (err) $display("TEST FAILED (start=1)");
        else $display("TEST PASSED (start=1)");

        $stop;
    end

endmodule: tb_syn_crack
