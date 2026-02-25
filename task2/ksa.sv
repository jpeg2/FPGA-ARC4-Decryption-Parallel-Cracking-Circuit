module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

    enum logic [3:0] {
        INIT,
        CHECK_I,
        READ_SI,
        WAIT_SI,
        CALC_J,
        READ_SJ,
        WAIT_SJ,
        WRITE_SI,
        WRITE_SJ,
        DONE
    } curr_state, next_state;

    logic start;
    logic init_i_j;
    logic [8:0] i;
    logic [8:0] j;
    logic [7:0] si;
    logic [7:0] sj;
    logic [7:0] key_index;
    logic update_i;
    logic update_j;
    logic update_si;
    logic update_sj;

    // I Register
    always_ff @(posedge clk) begin
        if (!rst_n || init_i_j) i <= 0;
        else if (update_i) i <= i + 1;
    end

    // J Register
    always_ff @(posedge clk) begin
        if (!rst_n || init_i_j) j <= 0;
        else if (update_j) j <= (j + si + key_index) % 256;
    end

    // Key Index Selection
    always_comb begin
        case (i % 3)
            0: key_index = key[23:16];
            1: key_index = key[15:8];
            2: key_index = key[7:0];
            default: key_index = 8'hxx;
        endcase
    end

    // SI Register
    always_ff @(posedge clk) begin
        if (update_si) si <= rddata;
    end

    // SJ Register
    always_ff @(posedge clk) begin
        if (update_sj) sj <= rddata;
    end

    // State Machine
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= INIT;
            start <= 0;
            rdy <= 1;
        end else if (en) begin
            start <= 1;
        end else if (start) begin
            curr_state <= next_state;
            if (curr_state == DONE) begin
                start <= 0;
                rdy   <= 1;
            end else begin
                rdy <= 0;
            end
        end
    end

    // Next-State Logic
    always_comb begin
        case (curr_state)
            INIT: begin
                init_i_j = 1;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 0;
                wren = 0;
                addr = 8'd0;
                wrdata = 8'd0;
                if (start) next_state = CHECK_I;
                else next_state = INIT;
            end
            CHECK_I: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 0;
                wren = 0;
                addr = 8'd0;
                wrdata = 8'd0;
                if (i < 256) next_state = READ_SI;
                else next_state = DONE;
            end
            READ_SI: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 1;
                update_sj = 0;
                wren = 0;
                addr = i[7:0];
                wrdata = 8'd0;
                next_state = WAIT_SI;
            end
            WAIT_SI: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 1;
                update_sj = 0;
                wren = 0;
                addr = i[7:0];
                wrdata = 8'd0;
                next_state = CALC_J;
            end
            CALC_J: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 1;
                update_si = 0;
                update_sj = 0;
                wren = 0;
                addr = 8'd0;
                wrdata = 8'd0;
                next_state = READ_SJ;
            end
            READ_SJ: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 1;
                wren = 0;
                addr = j[7:0];
                wrdata = 8'd0;
                next_state = WAIT_SJ;
            end
            WAIT_SJ: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 1;
                wren = 0;
                addr = j[7:0];
                wrdata = 8'd0;
                next_state = WRITE_SI;
            end
            WRITE_SI: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 0;
                wren = 1;
                addr = i[7:0];
                wrdata = sj;
                next_state = WRITE_SJ;
            end
            WRITE_SJ: begin
                init_i_j = 0;
                update_i = 1;
                update_j = 0;
                update_si = 0;
                update_sj = 0;
                wren    = 1;
                addr    = j[7:0];
                wrdata  = si;
                next_state = CHECK_I;
            end
            DONE: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 0;
                wren = 0;
                addr = 8'd0;
                wrdata = 8'd0;
                next_state = INIT;
            end
            default: begin
                init_i_j = 0;
                update_i = 0;
                update_j = 0;
                update_si = 0;
                update_sj = 0;
                wren = 0;
                addr = 8'd0;
                wrdata = 8'd0;                
                next_state = INIT;
            end
        endcase
    end
    
endmodule: ksa
