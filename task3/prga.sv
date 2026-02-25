module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    enum {
        IDLE,
        INIT_START,
        LOOP_CHECK,
        I_UPDATE,
        READ_SI_START,
        READ_SI_WAIT,
        J_UPDATE,
        READ_SJ_START,
        READ_SJ_WAIT,
        SWAP_WRITE_SI,
        SWAP_WRITE_SJ,
        LOAD_SIJ_START,
        LOAD_SIJ_WAIT,
        WRITE_PT_START,
        DONE
    } curr_state, next_state;

    logic start, init;
    logic [8:0] i, j, k;
    logic [7:0] si, sj, s_ij;
    logic update_i, update_j, update_si, update_sj, update_s_ij, update_k;
    logic [7:0] message_length;

    // rdy & start
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            rdy <= 1;
            start <= 0;
        end 
        else if (en) start <= 1;
        else if (start) begin
            curr_state <= next_state;
            if (curr_state == DONE) begin
                rdy <= 1;
                start <= 0;
            end
            else rdy <= 0;
        end
    end

    // Registers
    always_ff @(posedge clk) begin
        if (!rst_n || init) i <= 0;
        else if (update_i) i <= (i + 1) % 256;
    end

    always_ff @(posedge clk) begin
        if (!rst_n || init) j <= 0;
        else if (update_j) j <= (j + si) % 256;
    end

    always_ff @(posedge clk) begin
        if (update_si) si <= s_rddata;
    end

    always_ff @(posedge clk) begin
        if (update_sj) sj <= s_rddata;
    end

    always_ff @(posedge clk) begin
        if (update_s_ij) s_ij <= s_rddata;
    end

    always_ff @(posedge clk) begin
        if (!rst_n || init) k <= 1;
        else if (update_k) k <= k + 1;
    end

    always_ff @(posedge clk) begin
        if (ct_addr == 0) message_length <= ct_rddata;
    end

    // FSM
    always_comb begin
        case (curr_state)
            IDLE: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b00;
                s_addr = 8'b0;
                ct_addr = 8'b0;
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                if (start) next_state = INIT_START;
                else next_state = IDLE;
            end
            INIT_START: begin
                init = 1;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b01;
                s_addr = 8'b0;
                ct_addr = 8'b0;
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = message_length;
                next_state = LOOP_CHECK;
            end
            LOOP_CHECK: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b00;
                s_addr = 8'b0;
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                if (k < message_length) next_state = I_UPDATE;
                else next_state = DONE;
            end
            I_UPDATE: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b100000;
                {s_wren, pt_wren} = 2'b00;
                s_addr = 8'b0;
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = READ_SI_START;
            end
            READ_SI_START: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000100;
                {s_wren, pt_wren} = 2'b00;
                s_addr = i[7:0];
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = READ_SI_WAIT;
            end
            READ_SI_WAIT: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000100;
                {s_wren, pt_wren} = 2'b00;
                s_addr = i[7:0];
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = J_UPDATE;
            end
            J_UPDATE: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b010000;
                {s_wren, pt_wren} = 2'b00;
                s_addr = 8'b0;
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = READ_SJ_START;
            end
            READ_SJ_START: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000010;
                {s_wren, pt_wren} = 2'b00;
                s_addr = j[7:0];
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = READ_SJ_WAIT;
            end
            READ_SJ_WAIT: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000010;
                {s_wren, pt_wren} = 2'b00;
                s_addr = j[7:0];
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = SWAP_WRITE_SI;
            end
            SWAP_WRITE_SI: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b10;
                s_addr = i[7:0];
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = sj;
                pt_wrdata = 8'b0;
                next_state = SWAP_WRITE_SJ;
            end
            SWAP_WRITE_SJ: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b10;
                s_addr = j[7:0];
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = si;
                pt_wrdata = 8'b0;
                next_state = LOAD_SIJ_START;
            end
            LOAD_SIJ_START: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000001;
                {s_wren, pt_wren} = 2'b00;
                s_addr = (si + sj) % 256;
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = LOAD_SIJ_WAIT;
            end
            LOAD_SIJ_WAIT: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000001;
                {s_wren, pt_wren} = 2'b00;
                s_addr = (si + sj) % 256;
                ct_addr = k[7:0];
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = WRITE_PT_START;
            end
            WRITE_PT_START: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b001000;
                {s_wren, pt_wren} = 2'b01;
                s_addr = 8'b0;
                ct_addr = k[7:0];
                pt_addr = k[7:0];
                s_wrdata = 8'b0;
                pt_wrdata = s_ij ^ ct_rddata;
                next_state = LOOP_CHECK;
            end
            DONE: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b00;
                s_addr = 8'b0;
                ct_addr = 8'b0;
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = IDLE;
            end
            default: begin
                init = 0;
                {update_i, update_j, update_k, update_si, update_sj, update_s_ij} = 6'b000000;
                {s_wren, pt_wren} = 2'b00;
                s_addr = 8'b0;
                ct_addr = 8'b0;
                pt_addr = 8'b0;
                s_wrdata = 8'b0;
                pt_wrdata = 8'b0;
                next_state = IDLE;
            end
        endcase
    end

endmodule: prga
