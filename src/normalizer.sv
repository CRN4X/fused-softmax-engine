/*======================================================================
 *  Module      : normalizer
 *
 *  Description :
 *      Computes the normalized softmax output:
 *
 *          softmax_j = exp(z_j - z_max) / Σ exp(z_k - z_max)
 *
 *      This block performs:
 *         1. Leading-one normalization of the denominator (sum)
 *         2. Extracting mantissa bits for reciprocal LUT
 *         3. Looking up reciprocal of the normalized sum
 *         4. Multiplying e_j × reciprocal(sum)
 *         5. Shifting the product back by exponent k
 *         6. Outputting fixed-point softmax value
 *
 *  Parameters  :
 *      PROD_WIDTH          - Width of exp inputs (unused but preserved)
 *      SUM_WIDTH           - Width of accumulated denominator
 *      SUM_FRACTION_BITS   - Fraction bits in Σ exp values
 *      EXP_FRACTION_BITS   - Fraction bits in exp(z_j - z_max)
 *      EXP_BITS            - Width of e_j = EXP_FRACTION_BITS+1
 *      LUT_FRACTION_BITS   - Fraction precision for reciprocal LUT input
 *      RECIP_LUT_WIDTH     - Width of reciprocal LUT output
 *      SOFTMAX_OUT_WIDTH   - Final quantized softmax output width
 *
 *  Inputs      :
 *      clk, rst_           - Clock and active-low reset
 *      enable              - Latches intermediate values
 *      sum                 - Σ exp(z_k - z_max)
 *      e_j                 - exp(z_j - z_max)
 *
 *  Outputs     :
 *      softmax_j           - Normalized softmax output (Q format)
 *      valid               - Output valid pulse
 *
 *
 *======================================================================*/

module normalizer
#(
    parameter PROD_WIDTH            = 16,
    parameter SUM_WIDTH             = 18,
    parameter SUM_FRACTION_BITS     = 11,
    parameter EXP_FRACTION_BITS     = 11,
    parameter EXP_BITS              = EXP_FRACTION_BITS + 1,
    parameter LUT_FRACTION_BITS     = 6,
    parameter RECIP_LUT_WIDTH       = 9,
    parameter SOFTMAX_OUT_WIDTH     = 8
)
(
    output [SOFTMAX_OUT_WIDTH-1 : 0] softmax_j,
    output logic                     valid,

    input  [SUM_WIDTH-1:0]           sum,
    input  [EXP_BITS-1:0]            e_j,
    input                            enable,
    input                            clk,
    input                            rst_
);

    // ------------------------------------------------------------------
    // Internal constant/width definitions
    // ------------------------------------------------------------------
    localparam SUM_WIDTH_BITS     = $clog2(SUM_WIDTH);
    localparam INT_PROD_FRAC_BITS = EXP_FRACTION_BITS + RECIP_LUT_WIDTH - 1;
    localparam ZERO = {(INT_PROD_FRAC_BITS+2){1'b0}};

    // ------------------------------------------------------------------
    // 1. Leading-One Detector (LOD) for normalization
    // ------------------------------------------------------------------
    logic [SUM_WIDTH_BITS-1:0] idx_leading_one;
    logic                        leading_one_found;

    // Index LUT (integer to bitvector)
    localparam [4:0] INDEX [0:31] = '{
        0, 1, 2, 3, 4, 5, 6, 7,
        8, 9, 10, 11, 12, 13, 14, 15,
        16,17,18,19,20,21,22,23,
        24,25,26,27,28,29,30,31
    };

    always @(*) begin
        idx_leading_one   = ZERO[SUM_WIDTH_BITS-1 : 0];
        leading_one_found = 1'b0;

        for (int idx = SUM_WIDTH-1; idx >= 0; idx--) begin
            if (sum[idx] && !leading_one_found) begin
                idx_leading_one   = INDEX[idx][SUM_WIDTH_BITS-1:0];
                leading_one_found = 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------
    // 2. Normalize SUM to get mantissa
    // ------------------------------------------------------------------
    logic                        is_shift_right;
    logic [SUM_WIDTH_BITS-1:0]   shift_k;
    logic [SUM_WIDTH-1:0]        norm_sum;

    assign is_shift_right = (idx_leading_one >= (SUM_FRACTION_BITS - 1));
    assign shift_k = is_shift_right ?
                     (idx_leading_one - (SUM_FRACTION_BITS - 1)) :
                     ((SUM_FRACTION_BITS - 1) - idx_leading_one);

    assign norm_sum = is_shift_right ? (sum >> shift_k)
                                     : (sum << shift_k);

    // Extract mantissa for reciprocal LUT
    logic [LUT_FRACTION_BITS:0] m;
    assign m = norm_sum[SUM_FRACTION_BITS-1 -: (LUT_FRACTION_BITS+1)];

    // ------------------------------------------------------------------
    // 3. Reciprocal LUT
    // ------------------------------------------------------------------
    logic [RECIP_LUT_WIDTH-1:0] m_recip;

    recip_lut recip_lut_inst (
        .m_value   (m),
        .lut_output(m_recip)
    );

    // ------------------------------------------------------------------
    // 4. Multiply e_j × reciprocal(m) and latch
    //    int_prod stores the current product
    // ------------------------------------------------------------------
    logic [INT_PROD_FRAC_BITS+1:0] int_prod;
    logic [INT_PROD_FRAC_BITS+1:0] int_prod_shifted;

    assign int_prod_shifted =
        int_prod >> ((INT_PROD_FRAC_BITS - SOFTMAX_OUT_WIDTH) + shift_k);

    always @(posedge clk or negedge rst_) begin
        if (!rst_) begin
            int_prod <= ZERO;
            valid    <= 1'b0;
        end
        else if (enable) begin
            int_prod <= (e_j * m_recip);
            valid    <= 1'b1;
        end
        else begin
            valid <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // 5. Output
    // ------------------------------------------------------------------
    assign softmax_j =
        valid ? int_prod_shifted[SOFTMAX_OUT_WIDTH-1:0]
              : ZERO[SOFTMAX_OUT_WIDTH-1:0];

endmodule
