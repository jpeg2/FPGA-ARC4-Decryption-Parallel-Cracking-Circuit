module task3(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    logic en, rdy, pt_wren;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;

    enum {
        INIT,
        WAIT_RDY,
        EXECUTE,
        DONE
    } state;

    // keys
    assign key[23:10] = 14'b0;
    assign key[9:0]   = SW[9:0];

    // FSM
    always_ff @(posedge CLOCK_50) begin
        if (~KEY[3]) begin
            state <= INIT;
            en    <= 1'b1;
        end else begin
            case (state)
                INIT: begin
                    en    <= 1'b0;
                    state <= WAIT_RDY;
                end
                WAIT_RDY: state <= EXECUTE;
                EXECUTE: state <= (rdy ? DONE : EXECUTE);
                DONE: state <= DONE;
                default: state <= INIT;
            endcase
        end
    end

    ct_mem ct(.address(ct_addr), .clock(CLOCK_50), .data(8'd0), .wren(1'b0), .q(ct_rddata));

    pt_mem pt(.address(pt_addr), .clock(CLOCK_50), .data(pt_wrdata), .wren(pt_wren), .q(pt_rddata));

    arc4 a4(.clk(CLOCK_50), .rst_n(KEY[3]), .en(en), .rdy(rdy), .key(key), .ct_addr(ct_addr), 
    .ct_rddata(ct_rddata), .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));

endmodule: task3
