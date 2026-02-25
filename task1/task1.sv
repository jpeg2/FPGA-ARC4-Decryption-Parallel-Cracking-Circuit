module task1(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    logic [7:0] addr, wrdata;
    logic wren;
    logic rdy;
    logic en;

    enum logic [1:0] {
        RESET,
        ASSERT_EN,
        DEASSERT_EN
    } curr_state, next_state;

    // visible memory output for testing
    logic [7:0] q;
    assign LEDR[7:0] = q;
    assign LEDR[9:8] = 2'b00;

    // State register
    always_ff @(posedge CLOCK_50) begin
        if (!KEY[3]) curr_state <= RESET;
        else curr_state <= next_state;
    end

    // FSM combinational
    always_comb begin
        case (curr_state)
            RESET: begin
                en = 0;
                next_state = ASSERT_EN;
            end
            ASSERT_EN: begin
                en = 1; // one-cycle pulse
                next_state = DEASSERT_EN;
            end
            DEASSERT_EN: begin
                en = 0;        
                next_state = DEASSERT_EN; // stay here forever
            end
            default: begin
                en = 0;
                next_state = RESET;
            end
        endcase
    end

    // Memory instance
    s_mem s(.address(addr), .clock(CLOCK_50), .data(wrdata), .q(q));

    // init module
    init i(.clk(CLOCK_50), .rst_n(KEY[3]), .en(en), .rdy(rdy), .addr(addr), .wrdata(wrdata), .wren(wren));

endmodule: task1
