module task2(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    logic en_s, rdy_s;
    logic en_k, rdy_k;
    logic [7:0] addr_s, data_s;
    logic [7:0] addr_k, data_k;
    logic wren_s, wren_k;
    logic [7:0] q;

    logic sel_addr;   // selects addr_k or addr_s
    logic sel_data;   // selects data_k or data_s
    logic sel_wren;   // selects wren_k or wren_s

    logic [23:0] key;
    assign key[23:10] = 14'd0;
    assign key[9:0] = SW[9:0];

    // States
    enum {
        INIT,
        S_RDY1,
        S_RDY2,
        S_RDY3,
        S_WAIT,
        K_RDY1,
        K_RDY2,
        K_RDY3,
        K_WAIT,
        DONE
    } state;

    // State Machine
    always_ff @(posedge CLOCK_50) begin
        if (!KEY[3]) begin
            state     <= INIT;
        end else begin
            unique case (state)
                // INIT: wait for init module to be ready
                INIT: begin
                    en_s <= 0;
                    en_k <= 0;
                    if (rdy_s) state <= S_RDY1;
                    else state <= INIT;
                end
                // Fire INIT enable pulse
                S_RDY1: begin
                    en_s  <= 1;
                    state <= S_RDY2;
                end
                S_RDY2: begin
                    en_s  <= 0;
                    state <= S_RDY3;
                end
                S_RDY3: begin
                    en_s <= 0;
                    // Select INIT module
                    sel_addr <= 0;
                    sel_data <= 0;
                    sel_wren <= 0;
                    state <= S_WAIT;
                end
                // Wait for INIT (S-phase) to finish
                S_WAIT: begin
                    if (rdy_s) state <= K_RDY1;
                    else state <= S_WAIT;
                end
                // Fire KSA enable pulse
                K_RDY1: begin
                    en_k  <= 1;
                    state <= K_RDY2;
                end
                K_RDY2: begin
                    en_k  <= 0;
                    state <= K_RDY3;
                end
                K_RDY3: begin
                    en_s <= 0;
                    // Select KSA module
                    sel_addr <= 1;
                    sel_data <= 1;
                    sel_wren <= 1;
                    state <= K_WAIT;
                end
                // Wait for KSA (K-phase) to finish
                K_WAIT: begin
                    if (rdy_k) state <= DONE;
                    else state <= K_WAIT;
                end
                DONE: begin
                    state <= DONE;
                end
                default: state <= INIT;
            endcase
        end
    end

    // Instantiate init
    init i(.clk(CLOCK_50), .rst_n(KEY[3]), .en(en_s), .rdy(rdy_s), .addr(addr_s), .wrdata(data_s), .wren(wren_s));
    // Instantiate ksa
    ksa k(.clk(CLOCK_50), .rst_n(KEY[3]), .en(en_k), .rdy(rdy_k), .key(key), .addr(addr_k), .rddata(q), .wrdata(data_k), .wren(wren_k));
    // Instantiate mem
    s_mem s(.address(sel_addr ? addr_k : addr_s), .clock(CLOCK_50),
        .data(sel_data ? data_k : data_s),
        .wren(sel_wren ? wren_k : wren_s), .q(q));

endmodule: task2
