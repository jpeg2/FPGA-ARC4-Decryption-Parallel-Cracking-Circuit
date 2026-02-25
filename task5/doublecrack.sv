module doublecrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    logic start, init;
    // PT memory
    logic pt_wren;
    logic [7:0] pt_addr, pt_wrdata, pt_rddata;

    pt_mem pt(.address(pt_addr), .clock(clk), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));

    // CT memory for 2 crack modules
    logic [7:0] ct1_addr, ct2_addr;
    logic [7:0] ct1_rddata, ct2_rddata;
    logic ct1_wren, ct2_wren;

    ct_mem ct1(.address(ct1_addr), .clock(clk), .data(ct_rddata), .wren(ct1_wren), .q(ct1_rddata));
    ct_mem ct2(.address(ct2_addr), .clock(clk), .data(ct_rddata), .wren(ct2_wren), .q(ct2_rddata));

    // Crack modules
    logic en1, en2;
    logic rdy_c1, rdy_c2;
    logic [23:0] key_c1, key_c2;
    logic key_valid_c1, key_valid_c2;

    logic [7:0] c1_ct1_addr, c2_ct2_addr;
    logic [7:0] c1_ct1_rddata, c2_ct2_rddata;

    crack c1(.clk(clk), .rst_n(rst_n), .en(en1), .rdy(rdy_c1), .key(key_c1),
        .key_valid(key_valid_c1), .ct_addr(c1_ct1_addr), .ct_rddata(c1_ct1_rddata), .key_start(24'd0));

    crack c2(.clk(clk), .rst_n(rst_n), .en(en2), .rdy(rdy_c2),.key(key_c2), 
        .key_valid(key_valid_c2),.ct_addr(c2_ct2_addr), .ct_rddata(c2_ct2_rddata),.key_start(24'd1));

    // Arc4 to validate chosen answer key
    logic en_arc4, rdy_arc4;
    logic [7:0] ct_addr_arc4;

    arc4 a4_valid(.clk(clk), .rst_n(rst_n),.en(en_arc4), .rdy(rdy_arc4),.key(key), .ct_addr(ct_addr_arc4),
        .ct_rddata(ct_rddata),.pt_addr(pt_addr), .pt_rddata(pt_rddata),.pt_wrdata(pt_wrdata), .pt_wren(pt_wren));

    // CT fill controls
    enum {
        CTSEL_FILL, 
        CTSEL_CRACK
    } ct_sel;

    logic [8:0] ct_addr_fill;
    logic ct_wren_fill, update_ct_addr;

    // Top-level CT source mux
    logic ct_sel_top;

    always_comb begin
        if (ct_sel_top) ct_addr = ct_addr_fill[7:0];
        else ct_addr = ct_addr_arc4;
    end

    // Duplicate ct mem mux
    always_comb begin
        c1_ct1_rddata = ct1_rddata;
        c2_ct2_rddata = ct2_rddata;

        if (ct_sel == CTSEL_FILL) begin
            ct1_addr = ct_addr_fill[7:0];
            ct2_addr = ct_addr_fill[7:0];
            ct1_wren = ct_wren_fill;
            ct2_wren = ct_wren_fill;
        end else begin
            ct1_addr = c1_ct1_addr;
            ct2_addr = c2_ct2_addr;
            ct1_wren = 1'b0;
            ct2_wren = 1'b0;
        end
    end

    // CT fill pointer
    always_ff @(posedge clk) begin
        if (!rst_n || init) ct_addr_fill <= 0;
        else if (update_ct_addr) ct_addr_fill <= ct_addr_fill + 1;
    end

    enum { KEYSEL_C1, KEYSEL_C2, KEYSEL_NONE, KEYSEL_HOLD } key_sel;
    logic [23:0] answer_key;
    logic answer_key_valid;

    always_ff @(posedge clk) begin
        case (key_sel)
            KEYSEL_C1: begin
                answer_key <= key_c1;
                answer_key_valid <= key_valid_c1;
            end
            KEYSEL_C2: begin
                answer_key <= key_c2;
                answer_key_valid <= key_valid_c2;
            end
            KEYSEL_NONE: begin
                answer_key <= 24'hFFFFFF;
                answer_key_valid <= 1'b0;
            end
            default: ; // KEYSEL_HOLD keeps last value, so no case
        endcase
    end

    assign key = answer_key;
    assign key_valid = answer_key_valid;

    enum {
        IDLE,
        INIT,
        FILL_READ,
        FILL_WAIT,
        FILL_WRITE,
        FILL_INC,
        START_CRACK,
        WAIT_CRACK_START,
        WAIT_CRACK_DONE,
        CHECK_KEYS,
        ARC4_START,
        ARC4_WAIT_START,
        ARC4_WAIT_DONE,
        SUCCESS,
        FAIL
    } curr_state, next_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            rdy <= 1;
            start <= 0;
        end else if (en) begin
            start <= 1;
        end else if (start) begin
            curr_state <= next_state;
            if (curr_state == SUCCESS || curr_state == FAIL) begin
                start <= 0;
                rdy <= 1;
            end else begin
                rdy <= 0;
            end
        end
    end

    // FSM
    always_comb begin
        case (curr_state)
            IDLE: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b1000010;
                ct_sel = CTSEL_FILL;
                key_sel = KEYSEL_HOLD;
                next_state = (start ? INIT : IDLE);
            end
            INIT: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b1000010;
                ct_sel = CTSEL_FILL;
                key_sel = KEYSEL_NONE;
                next_state = FILL_READ;
            end
            FILL_READ: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_FILL;
                key_sel = KEYSEL_HOLD;
                next_state = (ct_addr_fill <= 255) ? FILL_WAIT : START_CRACK;
            end
            FILL_WAIT: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_FILL;
                key_sel = KEYSEL_HOLD;
                next_state = FILL_WRITE;
            end
            FILL_WRITE: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0100010;
                ct_sel = CTSEL_FILL;
                key_sel = KEYSEL_HOLD;
                next_state = FILL_INC;
            end
            FILL_INC: begin 
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0010010;
                ct_sel = CTSEL_FILL;
                key_sel = KEYSEL_HOLD;
                next_state = FILL_READ;
            end
            START_CRACK: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0001110;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = WAIT_CRACK_START;
            end
            WAIT_CRACK_START: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = (!rdy_c1 && !rdy_c2) ? WAIT_CRACK_DONE : WAIT_CRACK_START;
            end
            WAIT_CRACK_DONE: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = (rdy_c1 || rdy_c2) ? CHECK_KEYS : WAIT_CRACK_DONE;
            end
            CHECK_KEYS: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_CRACK;
                if (key_valid_c1) key_sel = KEYSEL_C1;
                else if (key_valid_c2) key_sel = KEYSEL_C2;
                else key_sel = KEYSEL_NONE;
                next_state = (key_sel == KEYSEL_NONE) ? FAIL : ARC4_START;
            end
            ARC4_START: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000001;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = ARC4_WAIT_START;
            end
            ARC4_WAIT_START: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000000;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = (!rdy_arc4) ? ARC4_WAIT_DONE : ARC4_WAIT_START;
            end
            ARC4_WAIT_DONE: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000000;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = (rdy_arc4) ? SUCCESS : ARC4_WAIT_DONE;
            end
            SUCCESS: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_HOLD;
                next_state = IDLE;
            end
            FAIL: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000010;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_NONE;
                next_state = IDLE;
            end
            default: begin
                {init, ct_wren_fill, update_ct_addr, en1, en2, ct_sel_top, en_arc4} = 7'b0000000;
                ct_sel = CTSEL_CRACK;
                key_sel = KEYSEL_NONE;
                next_state = IDLE;
            end
        endcase
    end

endmodule: doublecrack
