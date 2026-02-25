module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    logic rdy_init, rdy_ksa, rdy_prga;
    logic en_init, en_ksa, en_prga;
    logic s_wren;
    logic s_wren_init, s_wren_ksa, s_wren_prga;
    logic start;
    logic [7:0] s_addr;
    logic [7:0] s_wrdata;
    logic [7:0] s_rddata;
    logic [7:0] s_addr_init, s_addr_ksa, s_addr_prga;
    logic [7:0] s_wrdata_init, s_wrdata_ksa, s_wrdata_prga;

    enum {
        S_INIT, 
        S_KSA, 
        S_PRGA
        } s_mem_select;

    enum {
        IDLE,
        INIT_START,
        INIT_WAIT_START,
        INIT_WAIT_DONE,
        KSA_START,
        KSA_WAIT_START,
        KSA_WAIT_DONE,
        PRGA_START,
        PRGA_WAIT_START,
        PRGA_WAIT_DONE,
        DONE
    } curr_state, next_state;

    // S Memory Select
    always_comb begin
        case (s_mem_select)
            S_INIT: begin
                s_wren = s_wren_init;
                s_addr = s_addr_init;
                s_wrdata = s_wrdata_init;
            end
            S_KSA: begin
                s_wren = s_wren_ksa;
                s_addr = s_addr_ksa;
                s_wrdata = s_wrdata_ksa;
            end
            S_PRGA: begin
                s_wren = s_wren_prga;
                s_addr = s_addr_prga;
                s_wrdata = s_wrdata_prga;
            end
            default: begin
                s_wren = 1'b0;
                s_addr = 8'hFF;
                s_wrdata = 8'hFF;
            end
        endcase
    end

    // State Machine
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            start <= 0;
            rdy <= 1;
        end 
        else if (en) start <= 1;
        else if (start) begin
            curr_state <= next_state;
            if (curr_state == DONE) begin
                rdy   <= 1;
                start <= 0;
            end else rdy <= 0;
        end
    end

    // Next-State
    always_comb begin
        case (curr_state)
            IDLE: begin
                s_mem_select = S_INIT;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = start ? INIT_START : IDLE;
            end
            INIT_START: begin
                s_mem_select = S_INIT;
                {en_init, en_ksa, en_prga} = 3'b100;
                next_state = INIT_WAIT_START;
            end
            INIT_WAIT_START: begin
                s_mem_select = S_INIT;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = (!rdy) ? INIT_WAIT_DONE : INIT_WAIT_START;
            end
            INIT_WAIT_DONE: begin
                s_mem_select = S_INIT;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = rdy_init ? KSA_START : INIT_WAIT_DONE;
            end
            KSA_START: begin
                s_mem_select = S_KSA;
                {en_init, en_ksa, en_prga} = 3'b010;
                next_state = KSA_WAIT_START;
            end
            KSA_WAIT_START: begin
                s_mem_select = S_KSA;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = (!rdy) ? KSA_WAIT_DONE : KSA_WAIT_START;
            end
            KSA_WAIT_DONE: begin
                s_mem_select = S_KSA;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = rdy_ksa ? PRGA_START : KSA_WAIT_DONE;
            end
            PRGA_START: begin
                s_mem_select = S_PRGA;
                {en_init, en_ksa, en_prga} = 3'b001;
                next_state = PRGA_WAIT_START;
            end
            PRGA_WAIT_START: begin
                s_mem_select = S_PRGA;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = (!rdy) ? PRGA_WAIT_DONE : PRGA_WAIT_START;
            end
            PRGA_WAIT_DONE: begin
                s_mem_select = S_PRGA;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = rdy_prga ? DONE : PRGA_WAIT_DONE;
            end
            DONE: begin
                s_mem_select = S_PRGA;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = IDLE;
            end
            default: begin
                s_mem_select = S_INIT;
                {en_init, en_ksa, en_prga} = 3'b000;
                next_state = IDLE;
            end
        endcase
    end

    // Instantiate S_Mem
    s_mem s(.address(s_addr), .clock(clk), .data(s_wrdata), .wren(s_wren), .q(s_rddata));

    // Instantiate init
    init i(.clk(clk), .rst_n(rst_n), .en(en_init), .rdy(rdy_init), .addr(s_addr_init), .wrdata(s_wrdata_init), .wren(s_wren_init));

    // Instantiate ksa
    ksa k(.clk(clk), .rst_n(rst_n), .en(en_ksa), .rdy(rdy_ksa), .key(key), .addr(s_addr_ksa), .rddata(s_rddata), .wrdata(s_wrdata_ksa), .wren(s_wren_ksa));

    // Instantiate prga
    prga p(.clk(clk), .rst_n(rst_n), .en(en_prga), .rdy(rdy_prga), .key(key), .s_addr(s_addr_prga), .s_rddata(s_rddata), .s_wrdata(s_wrdata_prga),
    .s_wren(s_wren_prga), .ct_addr(ct_addr), .ct_rddata(ct_rddata), .pt_addr(pt_addr), .pt_rddata(pt_rddata), .pt_wrdata(pt_wrdata), .pt_wren(pt_wren));

endmodule: arc4
