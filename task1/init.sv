module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

    enum logic [2:0] {
        WAIT_ENABLE, 
        WRITE,
        INCREMENT, 
        CHECK_DONE, 
        HALT
    } curr_state, next_state;

    logic [8:0] counter;
    logic update_counter;
    logic start;

    // State register + start latch + rdy generation
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            curr_state <= WAIT_ENABLE;
            start <= 0;
            rdy <= 1;
        end else begin
            // latch the fact that enable happened
            if (en) start <= 1;

            // only advance states once we've started
            if (start) curr_state <= next_state;

            // rdy logic
            if (curr_state == HALT) rdy <= 1;
            else rdy <= 0;
        end
    end

    // Counter logic
    always_ff @(posedge clk) begin
        if (!rst_n) counter <= 0;
        else if (update_counter) counter <= counter + 1;
    end

    // Next-state + write-enable logic
    always_comb begin
        case (curr_state)
            WAIT_ENABLE: begin
                update_counter = 0;
                wren = 0;
                if (start) next_state = WRITE;
                else next_state = WAIT_ENABLE;
            end
            WRITE: begin
                update_counter = 0;
                wren = 1;
                next_state = INCREMENT;
            end
            INCREMENT: begin
                update_counter = 1;
                wren = 0;
                next_state = CHECK_DONE;
            end
            CHECK_DONE: begin
                update_counter = 0;
                wren = 0;
                if (counter > 255) next_state = HALT;
                else next_state = WRITE;
            end
            HALT: begin
                update_counter = 0;
                wren = 0;
                next_state = HALT;
            end
            default: begin
                update_counter = 0;
                wren = 0;
                next_state = WAIT_ENABLE;
            end
        endcase
    end

    assign addr   = counter[7:0];
    assign wrdata = counter[7:0];

endmodule: init
