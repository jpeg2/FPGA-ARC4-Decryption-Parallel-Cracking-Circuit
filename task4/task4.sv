module task4(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    logic rdy, en, key_valid, show;
    logic [7:0] ct_addr, ct_rddata;
    logic [23:0] key;

    enum {
        RESET,
        EN_HIGH,
        EN_LOW,
        CRACK_START,
        CRACK_END,
        DONE
    } curr_state, next_state;

    function automatic [6:0] hex_encode(input logic show, input logic key_valid, input logic [3:0] digit);
        if (!show) hex_encode = 7'b1111111;
        else if (!key_valid) hex_encode = 7'b0111111;
        else begin
            case (digit)
                4'h0: hex_encode = 7'b1000000;
                4'h1: hex_encode = 7'b1111001;
                4'h2: hex_encode = 7'b0100100;
                4'h3: hex_encode = 7'b0110000;
                4'h4: hex_encode = 7'b0011001;
                4'h5: hex_encode = 7'b0010010;
                4'h6: hex_encode = 7'b0000010;
                4'h7: hex_encode = 7'b1111000;
                4'h8: hex_encode = 7'b0000000;
                4'h9: hex_encode = 7'b0010000;
                4'hA: hex_encode = 7'b0001000;
                4'hB: hex_encode = 7'b0000011;
                4'hC: hex_encode = 7'b0100001;
                4'hD: hex_encode = 7'b0000110;
                4'hE: hex_encode = 7'b0000110;
                4'hF: hex_encode = 7'b0001110;
                default: hex_encode = 7'b0101010;
            endcase
        end
    endfunction

    assign HEX5 = hex_encode(show, key_valid, key[23:20]);
    assign HEX4 = hex_encode(show, key_valid, key[19:16]);
    assign HEX3 = hex_encode(show, key_valid, key[15:12]);
    assign HEX2 = hex_encode(show, key_valid, key[11:8]);
    assign HEX1 = hex_encode(show, key_valid, key[7:4]);
    assign HEX0 = hex_encode(show, key_valid, key[3:0]);

    always_ff @(posedge CLOCK_50) begin
        if (!KEY[3]) curr_state <= RESET;
        else curr_state <= next_state;
    end

    always_comb begin
        case (curr_state)
            RESET: begin
                en = 0;
                show = 0;
                LEDR[9] = 1;
                next_state = EN_HIGH;
            end
            EN_HIGH: begin
                en = 1;
                show = 0;
                LEDR[9] = 1;
                next_state = EN_LOW;
            end
            EN_LOW: begin
                en = 0;
                show = 0;
                LEDR[9] = 1;
                next_state = CRACK_START;
            end
            CRACK_START: begin
                en = 0;
                show = 0;
                LEDR[9] = 1;
                if (rdy) next_state = CRACK_END;
                else next_state = CRACK_START;
            end
            CRACK_END: begin
                en = 0;
                show = 0;
                LEDR[9] = 1;
                if (rdy) next_state = DONE;
                else next_state = CRACK_END;
            end
            DONE: begin
                en = 0;
                show = 1;
                LEDR[9] = 0;
                next_state = DONE;
            end
            default: begin
                en = 0;
                show = 0;
                LEDR[9] = 0;
                next_state = RESET;
            end
        endcase
    end

    ct_mem ct(.address(ct_addr), .clock(CLOCK_50), .data(8'd0), .wren(1'b0), .q(ct_rddata));

    crack c(.clk(CLOCK_50), .rst_n(KEY[3]), .en(en), .rdy(rdy), .key(key), .key_valid(key_valid), .ct_addr(ct_addr), .ct_rddata (ct_rddata));

endmodule: task4
