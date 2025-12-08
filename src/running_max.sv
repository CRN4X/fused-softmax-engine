//==========================================================================
// running_max.sv
// -------------------------------------------------------------------------
// Description:
//   Tracks the running maximum of a stream of PROD_WIDTH-bit signed inputs.
//
//   Each cycle when 'enable' is asserted, the module compares z_in against the
//   current maximum (curr_max) and updates curr_max if z_in is larger.
//
//   This is used inside the Softmax pipeline to compute:
//
//       max_j = max( z_j[0], z_j[1], ..., z_j[D_K-1] )
//
// Signed Comparison Handling:
//   Since SystemVerilog's < operator works correctly only on variables declared
//   as 'signed', but z_in and curr_max are declared as unsigned logic vectors,
//   this module performs a **manual signed compare** using:
//
//       sign_diff = z_in.sign XOR curr_max.sign
//
//       If signs differ:
//            Positive number is larger
//       Else:
//            Compare magnitudes normally
//
// Reset Behavior:
//   curr_max is initialized to the most negative value representable:
//
//       1 followed by all zeros
//       Example for 16-bit: 0x8000 (-32768)
//
//   This guarantees the first z_in will always replace curr_max.
//
// -------------------------------------------------------------------------

module running_max
#(
    parameter PROD_WIDTH = 16                // Width of the input/output values
)
(
    input                               clk,        // Clock
    input                               rst_,       // Async active-low reset
    input                               enable,     // Enables max update
    input  logic [PROD_WIDTH-1:0]       z_in,       // New input value (signed)
    output logic [PROD_WIDTH-1:0]       max_out     // Current running maximum
);

    // Internal register that stores the running maximum
    logic [PROD_WIDTH-1:0] curr_max;

    // Constant zero vector for constructing reset value
    localparam ZERO = {PROD_WIDTH{1'b0}};

    //--------------------------------------------------------------------------
    // Signed comparison logic (manual sign-aware compare)
    //
    // update_max = 1 → z_in is larger than curr_max
    //
    // If signs differ:
    //    curr_max.sign = 1 and z_in.sign = 0 → z_in is larger
    // If signs same:
    //    Compare as unsigned: magnitude compare is valid
    //--------------------------------------------------------------------------

    wire update_max = (z_in[PROD_WIDTH-1] ^ curr_max[PROD_WIDTH-1]) ?
                        curr_max[PROD_WIDTH-1] :        // different sign & curr_max negative? then update
                        (curr_max < z_in);              // same sign → compare normally

    // Drive output
    assign max_out = curr_max;

    //--------------------------------------------------------------------------
    // Sequential logic: track maximum
    //--------------------------------------------------------------------------

    always @(posedge clk or negedge rst_)
    begin
        if (!rst_) begin
            // Initialize to most negative signed value (1000...0)
            curr_max <= {1'b1, ZERO[PROD_WIDTH-2:0]};
        end
        else if (enable) begin
            if (update_max)
                curr_max <= z_in;        // Update max when z_in is larger
        end
    end

endmodule
