`timescale 1ps/1ps

module tb_rtl_task4();

    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    task4 DUT(.CLOCK_50 (CLOCK_50), .KEY (KEY), .SW(SW), .HEX0(HEX0), .HEX1(HEX1),
        .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    always #5 CLOCK_50 = ~CLOCK_50;

    logic [7:0] pt_ans[0:255];
    logic [23:0] answer_key;
    logic valid_answer;

    // Working reference solution, used to verify the correct test results
    task pseudocode_arc(input  logic [23:0] key24, output logic [7:0]  pt_out [0:255]);
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

        L = DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0];
        pt_out[0] = L;

        for (z = 1; z < L; z++) begin
            x = (x+1) % 256;
            y = (y+S[x]) % 256;

            temp = S[x];
            S[x] = S[y];
            S[y] = temp;

            pad = S[(S[x] + S[y]) % 256];
            pt_out[z] = pad ^ DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data[z];
        end
    endtask

    // Working reference solution, used to verify the correct test results
    task pseudocode_crack();
        logic [7:0] tmp_pt[0:255];
        logic readable;
        logic [7:0] L;
        integer i;

        answer_key = 24'hDEADFF;
        valid_answer = 0;

        for (logic [23:0] k = 24'h000000; k <= 24'hFFFFFF; k++) begin
            pseudocode_arc(k, tmp_pt);

            L = tmp_pt[0];
            readable = 1;

            for (i = 1; i < L; i++) begin
                if (tmp_pt[i] < 8'h20 || tmp_pt[i] > 8'h7E) begin
                    readable = 0;
                    break;
                end
            end

            if (readable) begin
                answer_key = k;
                valid_answer = 1;

                for (i = 0; i < L; i++)
                    pt_ans[i] = tmp_pt[i];

                break;
            end
        end
    endtask

    // Working reference solution, used to verify the correct test results
    function automatic [6:0] seg_hex(input logic valid, input logic [3:0] d);
        if (!valid) seg_hex = 7'b0111111;
        else begin
            case (d)
                4'h0: seg_hex = 7'b1000000;
                4'h1: seg_hex = 7'b1111001;
                4'h2: seg_hex = 7'b0100100;
                4'h3: seg_hex = 7'b0110000;
                4'h4: seg_hex = 7'b0011001;
                4'h5: seg_hex = 7'b0010010;
                4'h6: seg_hex = 7'b0000010;
                4'h7: seg_hex = 7'b1111000;
                4'h8: seg_hex = 7'b0000000;
                4'h9: seg_hex = 7'b0010000;
                4'hA: seg_hex = 7'b0001000;
                4'hB: seg_hex = 7'b0000011;
                4'hC: seg_hex = 7'b0100001;
                4'hD: seg_hex = 7'b0000110;
                4'hE: seg_hex = 7'b0000110;
                4'hF: seg_hex = 7'b0001110;
                default: seg_hex = 7'b1111111;
            endcase
        end
    endfunction

    // Test Sequence
    integer i;
    logic err;
    logic [6:0] gold0, gold1, gold2, gold3, gold4, gold5;

    initial begin
        CLOCK_50 = 0;
        err = 0;

        // TEST 1
        $display("Starting Test 1");
        KEY = 0;
        SW = 0;

        $readmemh("../task3/test1.memh", DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        #1;
        pseudocode_crack();
        #5;

        // Start
        KEY[3] = 1;

        // Wait until LEDR[9] = 0 (DONE)
        wait (LEDR[9] == 0);

        // Compute expected HEX values
        gold0 = seg_hex(valid_answer, answer_key[3:0]);
        gold1 = seg_hex(valid_answer, answer_key[7:4]);
        gold2 = seg_hex(valid_answer, answer_key[11:8]);
        gold3 = seg_hex(valid_answer, answer_key[15:12]);
        gold4 = seg_hex(valid_answer, answer_key[19:16]);
        gold5 = seg_hex(valid_answer, answer_key[23:20]);

        // Compare hex
        if (HEX0 != gold0) begin $display("HEX0 mismatch"); err = 1; end
        if (HEX1 != gold1) begin $display("HEX1 mismatch"); err = 1; end
        if (HEX2 != gold2) begin $display("HEX2 mismatch"); err = 1; end
        if (HEX3 != gold3) begin $display("HEX3 mismatch"); err = 1; end
        if (HEX4 != gold4) begin $display("HEX4 mismatch"); err = 1; end
        if (HEX5 != gold5) begin $display("HEX5 mismatch"); err = 1; end

        for (i = 0; i < pt_ans[0]; i++) begin
            if (DUT.c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] != pt_ans[i]) begin
                $display("Internal mismatch at idx %0d", i);
                err = 1;
            end
        end

        if (err) $display("TEST 1 FAILED");
        else $display("TEST 1 PASSED");

        #10;

        // TEST 2
        $display("Starting Test 2");
        err = 0;
        KEY = 0;

        $readmemh("../task3/test2.memh", DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        #1;
        pseudocode_crack();
        #5;

        KEY[3] = 1;
        wait (LEDR[9] == 0);

        gold0 = seg_hex(valid_answer, answer_key[3:0]);
        gold1 = seg_hex(valid_answer, answer_key[7:4]);
        gold2 = seg_hex(valid_answer, answer_key[11:8]);
        gold3 = seg_hex(valid_answer, answer_key[15:12]);
        gold4 = seg_hex(valid_answer, answer_key[19:16]);
        gold5 = seg_hex(valid_answer, answer_key[23:20]);

        if (HEX0 != gold0) err = 1;
        if (HEX1 != gold1) err = 1;
        if (HEX2 != gold2) err = 1;
        if (HEX3 != gold3) err = 1;
        if (HEX4 != gold4) err = 1;
        if (HEX5 != gold5) err = 1;

        for (i = 0; i < pt_ans[0]; i++) if (DUT.c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[i] != pt_ans[i]) err = 1;

        if (err) $display("TEST 2 FAILED");
        else $display("TEST 2 PASSED");

        $display("ALL TASK4 RTL TESTS COMPLETE");
        $stop;
    end

endmodule: tb_rtl_task4
