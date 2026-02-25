module crack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    logic start, init;
    logic pt_wren;
    logic [7:0] pt_addr, pt_wrdata, pt_rddata;
    logic pt_wren_arc4, pt_wren_crack;
    logic [7:0] pt_addr_arc4;
    logic [8:0] pt_addr_crack;
    logic pt_addr_crack_reset;
    assign pt_wren_crack = 1'b0;
    logic en_arc4, rdy_arc4;
    logic [24:0] test_key;
    logic [7:0]  pt_length;
    assign key = test_key[23:0];
    logic update_test_key, update_pt_length, pt_addr_increment;

    enum {
        PTSEL_ARC4, 
        PTSEL_CRACK0, 
        PTSEL_CRACK1 
    } pt_addr_select;

    enum {
        IDLE,
        INIT,
        TESTKEY_CHECK,
        ARC4_START,
        ARC4_WAIT_START,
        ARC4_WAIT_DONE,
        PTLEN_READ_START,
        PTLEN_WAIT,
        CHECK_PT_LENGTH,
        HUMAN_READABLE_CHECK,
        PT_INCREMENT,
        TESTKEY_INCREMENT,
        CRACK_SUCCESSFUL,
        CRACK_UNSUCCESSFUL
    } curr_state, next_state;

    // Test_key Register
    always_ff @(posedge clk) begin
        if (!rst_n || init) test_key <= 0;
        else if (update_test_key) test_key <= test_key + 1;
    end

    // Pt_addr_crack Register
    always_ff @(posedge clk) begin
        if (!rst_n || init || pt_addr_crack_reset) pt_addr_crack <= 1;
        else if (pt_addr_increment) pt_addr_crack <= pt_addr_crack + 1;
    end

    // Pt_length Register
    always_ff @(posedge clk) begin
        if (update_pt_length) pt_length <= pt_rddata;
    end

    // FSM
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            start <= 0;
            rdy <= 1;
        end else if (en) start <= 1;
        else if (start) begin
            curr_state <= next_state;
            if (curr_state == CRACK_SUCCESSFUL || curr_state == CRACK_UNSUCCESSFUL) begin
                start <= 0;
                rdy   <= 1;
            end else rdy <= 0;
        end
    end

    // Key_valid Flag
    always_ff @(posedge clk) begin
        if (next_state == CRACK_SUCCESSFUL) key_valid <= 1'b1;
        if (next_state == CRACK_UNSUCCESSFUL) key_valid <= 1'b0;
        if (next_state == INIT) key_valid <= 1'b0;
    end

    // Mux for PT memory address and wren
    always_comb begin
        case (pt_addr_select)
            PTSEL_ARC4: begin
                pt_addr = pt_addr_arc4;
                pt_wren = pt_wren_arc4;
            end
            PTSEL_CRACK0: begin
                pt_addr = 0;
                pt_wren = pt_wren_crack;
            end
            PTSEL_CRACK1: begin
                pt_addr = pt_addr_crack[7:0];
                pt_wren = pt_wren_crack;
            end
            default: begin
                pt_addr = 8'hFF;
                pt_wren = 0;
            end
        endcase
    end

    // Next-State
    always_comb begin
        case (curr_state)
            IDLE: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_ARC4;
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b100000;
                pt_addr_select = PTSEL_ARC4;
                next_state = TESTKEY_CHECK;
            end
            TESTKEY_CHECK: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_ARC4;
                if (test_key <= 25'hFFFFFF) next_state = ARC4_START;
                else next_state = CRACK_UNSUCCESSFUL;
            end
            ARC4_START: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b010000;
                pt_addr_select = PTSEL_ARC4;
                next_state = ARC4_WAIT_START;
            end
            ARC4_WAIT_START: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_ARC4;
                if (!rdy_arc4) next_state = ARC4_WAIT_DONE;
                else next_state = ARC4_WAIT_START;
            end
            ARC4_WAIT_DONE: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_ARC4;
                if (rdy_arc4) next_state = PTLEN_READ_START;
                else next_state = ARC4_WAIT_DONE;
            end
            PTLEN_READ_START: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000100;
                pt_addr_select = PTSEL_CRACK0;
                next_state = PTLEN_WAIT;
            end
            PTLEN_WAIT: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000101;
                pt_addr_select = PTSEL_CRACK0;
                next_state = CHECK_PT_LENGTH;
            end
            CHECK_PT_LENGTH: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_CRACK1;
                if (pt_addr_crack < {1'b0, pt_length}) next_state = HUMAN_READABLE_CHECK;
                else next_state = CRACK_SUCCESSFUL;
            end
            HUMAN_READABLE_CHECK: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_CRACK1;
                if (pt_rddata < 8'h20 || pt_rddata > 8'h7E) next_state = TESTKEY_INCREMENT;
                else next_state = PT_INCREMENT; 
            end
            PT_INCREMENT: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000010;
                pt_addr_select = PTSEL_CRACK1;
                next_state = CHECK_PT_LENGTH;
            end
            TESTKEY_INCREMENT: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b001000;
                pt_addr_select = PTSEL_ARC4;
                next_state = TESTKEY_CHECK;
            end
            CRACK_SUCCESSFUL: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_CRACK1;
                next_state = IDLE;
            end
            CRACK_UNSUCCESSFUL: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                pt_addr_select = PTSEL_CRACK1;
                next_state = IDLE;
            end
            default: begin
                {init, en_arc4, update_test_key, update_pt_length, pt_addr_increment, pt_addr_crack_reset} = 6'b000000;
                next_state = IDLE;
            end
        endcase
    end

    pt_mem pt(.address(pt_addr), .clock(clk), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));

    arc4 a4(.clk(clk), .rst_n(rst_n), .en(en_arc4), .rdy(rdy_arc4), .key(test_key[23:0]),.ct_addr(ct_addr),
    .ct_rddata(ct_rddata), .pt_addr(pt_addr_arc4), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren_arc4));

endmodule: crack
