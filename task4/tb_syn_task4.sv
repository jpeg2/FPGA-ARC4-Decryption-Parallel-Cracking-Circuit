`timescale 1ps/1ps

module tb_syn_task4();

    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    task4 DUT(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    always #5 CLOCK_50 = ~CLOCK_50;

    // Working reference solution, used to verify the correct test results
    task pseudocode_arc(input logic [23:0] key24, output logic [7:0] pt_out [0:255]);
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

        L = DUT.\ct|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[0];

        pt_out[0] = L;

        for (z = 1; z < L; z++) begin
            x = (x + 1) % 256;
            y = (y + S[x]) % 256;

            temp = S[x];
            S[x] = S[y];
            S[y] = temp;

            pad = S[(S[x] + S[y]) % 256];

            pt_out[z] = pad ^ DUT.\ct|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[z];
        end
    endtask

    logic [23:0] answer_key;
    logic [7:0]  pt_ans [0:255];
    logic valid_answer;

    // Working reference solution, used to verify the correct test results
    task pseudocode_crack();
        logic [7:0] tmp[0:255];
        logic readable;
        logic [7:0] L, c;
        integer i;

        answer_key   = 24'h000000;
        valid_answer = 0;

        for (logic [23:0] k = 24'h000000; k <= 24'hFFFFFF; k++) begin
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
                answer_key = k;
                valid_answer = 1;
                for (i = 0; i < L; i++) pt_ans[i] = tmp[i];
                break;
            end
        end
    endtask

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

    integer i;
    logic err;
    logic [6:0] gold0, gold1, gold2, gold3, gold4, gold5;

    initial begin
        CLOCK_50 = 0;
        SW = 0;

        // TEST 1
        $display("Starting SYNTH TEST 1");
        err = 0;
        KEY = 0;

        $readmemh("../task3/test1.memh", DUT.\ct|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem);

        #1;
        pseudocode_crack();
        #10;

        // Start machine
        KEY[3] = 1;

        // Wait for DONE
        wait (LEDR[9] == 0);

        // compute expected HEX values
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

        for (i = 0; i < pt_ans[0]; i++) begin
            if (DUT.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[i] != pt_ans[i]) begin
                $display("Mismatch at idx %0d", i);
                err = 1;
            end
        end

        if (err) $display("SYNTH TEST 1 FAILED");
        else $display("SYNTH TEST 1 PASSED");

        #20;

        // TEST 2
        $display("Starting SYNTH TEST 2");
        err = 0;
        KEY = 0;

        $readmemh("../task3/test2.memh", DUT.\ct|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem);

        #1;
        pseudocode_crack();
        #10;

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

        for (i = 0; i < pt_ans[0]; i++) if (DUT.\pt|altsyncram_component|auto_generated|altsyncram1|ram_block3a0 .ram_core0.ram_core0.mem[i] != pt_ans[i]) err = 1;

        if (err) $display("SYNTH TEST 2 FAILED");
        else $display("SYNTH TEST 2 PASSED");

        $stop;
    end

endmodule: tb_syn_task4
