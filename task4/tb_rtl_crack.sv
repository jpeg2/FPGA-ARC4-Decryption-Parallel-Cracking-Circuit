`timescale 1ps/1ps

module tb_rtl_crack();

    logic clk;
    logic rst_n;
    logic en;
    logic rdy;
    logic key_valid;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;

    crack DUT(.clk(clk), .rst_n(rst_n), .en(en), .rdy(rdy), .key(key), .key_valid(key_valid), .ct_addr(ct_addr), .ct_rddata(ct_rddata));

    always #5 clk = ~clk;
    logic [7:0] ct_mem_array [0:255];

    initial begin
        #1;
        forever begin
            ct_rddata = ct_mem_array[ct_addr];
            #10;
        end
    end

    // Working reference solution, used to verify correct test results
    task pseudocode_arc(input  logic [23:0] s_key, output logic [7:0]  pt_array [0:255]);
        logic [7:0] S[0:255];
        logic [7:0] key_bytes[0:2];
        logic [7:0] temp;
        integer x, y, z;
        logic [7:0] pad;
        logic [7:0] L;

        key_bytes[0] = s_key[23:16];
        key_bytes[1] = s_key[15:8];
        key_bytes[2] = s_key[7:0];

        for (x = 0; x < 256; x++)
            S[x] = x;

        y = 0;
        for (x = 0; x < 256; x++) begin
            y = (y + S[x] + key_bytes[x % 3]) % 256;
            temp = S[x];
            S[x] = S[y];
            S[y] = temp;
        end

        x = 0;
        y = 0;
        L = ct_mem_array[0];
        pt_array[0] = L;

        for (z = 1; z < L; z++) begin
            x = (x + 1) % 256;
            y = (y + S[x]) % 256;

            temp = S[x];
            S[x] = S[y];
            S[y] = temp;

            pad = S[(S[x] + S[y]) % 256];
            pt_array[z] = pad ^ ct_mem_array[z];
        end
    endtask

    logic [23:0] answer_key;
    logic [7:0]  pt_ans_array [0:255];
    logic valid_answer;

    // Working reference solution, used to verify correct test results
    task pseudocode_crack();
        logic readable;
        logic [7:0] pt_tmp[0:255];
        integer idx;
        logic [7:0] L;

        answer_key = 24'hDEADFF;
        valid_answer = 0;

        for (logic [23:0] test_k = 24'h000000; test_k <= 24'hFFFFFF; test_k++) begin
            pseudocode_arc(test_k, pt_tmp);

            L = pt_tmp[0];
            readable = 1;

            for (idx = 1; idx < L; idx++) begin
                if (pt_tmp[idx] < 8'h20 || pt_tmp[idx] > 8'h7E) begin
                    readable = 0;
                    break;
                end
            end

            if (readable) begin
                answer_key = test_k;
                valid_answer = 1;
                for (idx = 0; idx < L; idx++)
                    pt_ans_array[idx] = pt_tmp[idx];
                break;
            end
        end
    endtask

    logic err;
    integer i;

    // Test sequence
    initial begin
        clk = 0;
        rst_n = 0;
        en = 0;
        err = 0;

        $readmemh("../task3/test1.memh", ct_mem_array);

        pseudocode_crack();

        #20 rst_n = 1;

        if (rdy != 1) begin
            $display("ERROR: rdy should be 1 after reset");
            $stop;
        end

        // Pulse en
        #10 en = 1;
        #10 en = 0;

        // Wait for finish
        wait (rdy == 1);

        $display("Checking DUT Output");

        if (key != answer_key) begin
            $display("ERROR: Computed key mismatch. Expected = %h, Got = %h", answer_key, key);
            err = 1;
        end

        for (i = 0; i < pt_ans_array[0]; i++) begin
            if (DUT.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] != pt_ans_array[i]) begin
                $display("Mismatch at index %0d: expected %h, got %h",
                         i,
                         pt_ans_array[i],
                         DUT.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);
                err = 1;
            end
        end

        if (err) $display("TEST FAILED");
        else $display("TEST PASSED");

        $stop;
    end

endmodule: tb_rtl_crack
