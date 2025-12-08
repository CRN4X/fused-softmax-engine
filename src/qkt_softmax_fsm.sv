
//==========================================================================
// qkt_softmax_fsm.sv
// -------------------------------------------------------------------------
// Description:
//   Finite State Machine controlling the 3-pass QKT Softmax pipeline.
//   The FSM sequences PASS1 → PASS2 → PASS3 in response to a start pulse.
//   Each pass asserts its corresponding enable signal and waits for the
//   matching done signal before transitioning to the next stage.
//
// Operation:
//   - IDLE  : Wait for 'start'.
//   - PASS1 : Assert enable_pass1 until done_pass1 = 1.
//   - PASS2 : Assert enable_pass2 until done_pass2 = 1.
//   - PASS3 : Assert enable_pass3 until done_pass3 = 1.
//   - Return to IDLE.
//
//
// Notes:
//   - Designed for use inside the QKT Softmax accelerator.
//   - Each pass corresponds to one pipeline phase of computation.
//   - Enum-based state machine for readability and synthesis clarity.
//
// -------------------------------------------------------------------------

module qkt_softmax_fsm(

    // Enable signals for the three processing passes
    output logic enable_pass1,
    output logic enable_pass2,
    output logic enable_pass3,

    // Done signals from each stage
    input  logic done_pass1,
    input  logic done_pass2,
    input  logic done_pass3,

    // External start pulse
    input  logic start,

    // Clock and active-low reset
    input        clk,
    input        rst_
);

    //----------------------------------------------------------------------
    // State encoding
    //----------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,       // Wait for start
        PASS1,      // Execute pass 1
        PASS2,      // Execute pass 2
        PASS3       // Execute pass 3
    } state_def;

    state_def state, next_state;

    //----------------------------------------------------------------------
    // Sequential state transition (synchronous)
    //----------------------------------------------------------------------
    always @(posedge clk or negedge rst_) begin
        if (!rst_) begin
            state <= IDLE;          // Reset -> go to IDLE
        end
        else begin
            state <= next_state;    // Normal transition
        end
    end

    //----------------------------------------------------------------------
    // Combinational next-state logic and output enables
    //----------------------------------------------------------------------
    always @(*) begin

        // Default outputs (inactive)
        enable_pass1 = 1'b0;
        enable_pass2 = 1'b0;
        enable_pass3 = 1'b0;

        // Default next state = stay where you are
        next_state   = state;

        case (state)

            //------------------------------------------------------------------
            // IDLE: wait for start to be asserted
            //------------------------------------------------------------------
            IDLE: begin
                if (start) begin
                    next_state = PASS1;
                end
            end

            //------------------------------------------------------------------
            // PASS1 active until done_pass1 is asserted
            //------------------------------------------------------------------
            PASS1: begin
                enable_pass1 = 1'b1;        // Assert pass-1 enable

                if (done_pass1) begin
                    next_state = PASS2;     // Move to next stage
                end
            end

            //------------------------------------------------------------------
            // PASS2 active until done_pass2 is asserted
            //------------------------------------------------------------------
            PASS2: begin
                enable_pass2 = 1'b1;

                if (done_pass2) begin
                    next_state = PASS3;
                end
            end

            //------------------------------------------------------------------
            // PASS3 active until done_pass3 is asserted
            //------------------------------------------------------------------
            PASS3: begin
                enable_pass3 = 1'b1;

                if (done_pass3) begin
                    next_state = IDLE;      // Completed all passes
                end
            end

            //------------------------------------------------------------------
            // Safety default (should never hit)
            //------------------------------------------------------------------
            default: begin
                enable_pass1 = 1'b0;
                enable_pass2 = 1'b0;
                enable_pass3 = 1'b0;
                next_state   = IDLE;
            end
        endcase
    end

endmodule
