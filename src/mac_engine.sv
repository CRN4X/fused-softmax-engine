//==========================================================================
// mac_engine.sv
// -------------------------------------------------------------------------
// Description:
//   Multiply-Accumulate (MAC) engine used in the QKT Softmax pipeline.
//   Performs D_K sequential MAC operations:
//
//        z_j = Σ ( q_i[k] * k_j[k] )   ,  for k = 0 to D_K-1
//
//   Inputs q_i and k_j are INT8 (Q0.7 signed). Their product produces
//   a Q1.14 intermediate, which is rounded and scaled down to Q8.7.
//
//
// Fixed-Point Pipeline:
//   raw_prod     = q_i * k_j               → Q1.14
//   round        = ±(2^(7-1))              → sign-aware rounding factor
//   rounded_prod = (raw_prod + round) >>> 7  → Q8.7
//   z_j accumulates rounded_prod for D_K cycles.
//
// Notes:
//   - PROD_SHIFT = RAW_FRAC - TARGET_FRAC = 14 - 7 = 7
//   - Rounded_prod is sign extended since '>>>' is arithmetic shift.
//   - Scaling by sqrt(D_K) can be applied after accumulation externally.
//
// -------------------------------------------------------------------------

module mac_engine
#(
    parameter WIDTH       = 8,     // Bit-width of INT8 inputs
    parameter D_K         = 64,    // Length of vector for MAC
    parameter PROD_WIDTH  = 16     // Width of accumulated Zj output
)
(
    input  clk,                                      // Clock
    input  rst_,                                     // Async active-low reset
    input  enable,                                   // Enables MAC operation
    input  signed [WIDTH-1:0] q_i,                   // Qi element
    input  signed [WIDTH-1:0] k_j,                   // Kj element
    output logic signed [PROD_WIDTH-1:0] z_j,        // Accumulated output Zj
    output logic done_mac                            // Completion flag
);

    //--------------------------------------------------------------------------
    // Local parameters and derived constants
    //--------------------------------------------------------------------------

    localparam ZERO                     = {PROD_WIDTH{1'b0}};         
    localparam COUNT_WIDTH              = $clog2(D_K) + 1;       // Enough bits to count 0..D_K-1
    localparam int SQRT_DK              = $rtoi($sqrt(D_K));     // For later scaling
    localparam RAW_PROD_FRAC_BITS       = 2 * (WIDTH - 1);       // Q0.7 * Q0.7 → Q1.14
    localparam TARGET_PROD_FRAC_BITS    = 7;                     // We want Q8.7
    localparam PROD_SHIFT               = RAW_PROD_FRAC_BITS - TARGET_PROD_FRAC_BITS;
    localparam PROD_SCALING_FACTOR      = 2 ** TARGET_PROD_FRAC_BITS;
    localparam PROD_ROUNDING_FACTOR     = PROD_SCALING_FACTOR / 2;
    localparam SCALING_SHIFT            = $clog2(SQRT_DK);

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------

    logic [COUNT_WIDTH-1:0] counter;                    // Counts how many MACs completed
    logic signed [RAW_PROD_FRAC_BITS+1:0] prod;         // Intermediate product
    logic signed [RAW_PROD_FRAC_BITS+1:0] round;        // signed rounding factor 
    logic signed [RAW_PROD_FRAC_BITS+1:0] rounded_prod; // final rounded product

    //--------------------------------------------------------------------------
    // Raw multiplication (Q0.7 × Q0.7 = Q1.14)
    //--------------------------------------------------------------------------

    assign prod = q_i * k_j;

    //--------------------------------------------------------------------------
    // Sign-aware rounding: Round-to-nearest
    //--------------------------------------------------------------------------

    assign round = prod[PROD_WIDTH-1] 
                   ? $signed(-PROD_ROUNDING_FACTOR)     // Negative → subtract rounding factor
                   : $signed(PROD_ROUNDING_FACTOR);      // Positive → add rounding factor

    //--------------------------------------------------------------------------
    // Scale down from Q1.14 → Q8.7 (arithmetic shift)
    //--------------------------------------------------------------------------

    assign rounded_prod = (prod + round) >>> PROD_SHIFT;

    //--------------------------------------------------------------------------
    // Sequential MAC accumulation
    //--------------------------------------------------------------------------

    always @(posedge clk or negedge rst_)
    begin
        if (!rst_) begin
            // Reset state
            z_j      <= ZERO;
            counter  <= ZERO[COUNT_WIDTH-1:0];
            done_mac <= 1'b0;
        end 
        else if (enable && !done_mac) begin

            // Start of new accumulation
            if (counter == 0)
                z_j <= rounded_prod;
            else
                z_j <= z_j + rounded_prod;

            // If D_K iterations completed → done
            if (counter == D_K - 1) begin
                done_mac <= 1'b1;
                counter  <= 0;
            end
            else begin
                counter <= counter + 1;
            end
        end
        else if (done_mac) begin
            // Clear done flag next cycle
            done_mac <= 1'b0;
        end
    end

endmodule
