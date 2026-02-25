`timescale 1ps/1ps

module tb_rtl_task5();

    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    task5 DUT(.CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    always #5 CLOCK_50 = ~CLOCK_50;

    // ARC4 reference
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

        L = DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data[0];
        pt_out[0] = L;

        for (z = 1; z < L; z++) begin
            x = (x + 1) % 256;
            y = (y + S[x]) % 256;

            temp = S[x];
            S[x] = S[y];
            S[y] = temp;

            pad = S[(S[x] + S[y]) % 256];

            pt_out[z] = pad ^ DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data[z];
        end
    endtask

    // crack reference
    logic [23:0] answer_key;
    logic [7:0]  pt_ans [0:255];
    logic valid_answer;

    task pseudocode_crack();
        logic readable;
        logic [7:0] tmp[0:255];
        logic [7:0] L, c;
        integer i;
        logic [23:0] k;

        answer_key = 24'h000000;
        valid_answer = 0;

        for (k = 24'h000000; k <= 24'hFFFFFF; k++) begin
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

    function automatic [6:0] seg_hex(input logic ok, input logic [3:0] d);
        if (!ok) seg_hex = 7'b0111111;
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

    integer idx;
    logic err;

    task verify_hex();
        if (HEX0 != seg_hex(valid_answer, answer_key[3:0])) err = 1;
        if (HEX1 != seg_hex(valid_answer, answer_key[7:4])) err = 1;
        if (HEX2 != seg_hex(valid_answer, answer_key[11:8])) err = 1;
        if (HEX3 != seg_hex(valid_answer, answer_key[15:12])) err = 1;
        if (HEX4 != seg_hex(valid_answer, answer_key[19:16])) err = 1;
        if (HEX5 != seg_hex(valid_answer, answer_key[23:20])) err = 1;
    endtask

    task verify_pt();
        for (idx = 0; idx < pt_ans[0]; idx++) begin
            if (DUT.c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[idx] != pt_ans[idx]) begin
                err = 1;
                $display("PT mismatch @%0d: expected=%h got=%h", idx, pt_ans[idx], DUT.c.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[idx]);
            end
        end
    endtask

    // Test Sequence
    initial begin
        CLOCK_50 = 0;
        SW = 0;

        // TEST 1
        $display("TASK5 RTL: TEST1");
        err = 0;
        KEY = 0;

        $readmemh("../task3/test1.memh", DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        #1;
        pseudocode_crack();
        #10 KEY[3] = 1;

        wait (LEDR[9] == 0);

        verify_hex();
        verify_pt();

        if (err) $display("TEST1 FAILED");
        else $display("TEST1 PASSED");

        // TEST 2
        $display("TASK5 RTL: TEST2");
        err = 0;
        KEY = 0;

        $readmemh("../task3/test2.memh", DUT.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);

        #1;
        pseudocode_crack();
        #10 KEY[3] = 1;

        wait (LEDR[9] == 0);

        verify_hex();
        verify_pt();

        if (err) $display("TEST2 FAILED");
        else $display("TEST2 PASSED");

        $display("TASK5 RTL: ALL TESTS COMPLETE");
        $stop;
    end

endmodule: tb_rtl_task5
