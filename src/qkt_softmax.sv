// ============================================================================
// QKT + Softmax Computation Block
// -----------------------------------------------------------------------------
// Computes:  softmax( Q·Kᵀ / √d_k )
// Pipeline has 3 passes:
//   PASS1 → Compute dot-product for all Q-K pairs and store z_j
//   PASS2 → Compute running-max and sum of exp(z_j - z_max)
//   PASS3 → Normalize exponentials to produce final softmax output
//
// Fully parameterized with separate widths for input, products, sums,
// exponent fractions, LUT widths, and output softmax precision.
//
// All arithmetic is performed in fixed-point (signed Qm.n formats)
// ============================================================================

module qkt_softmax #(
    parameter INPUT_WIDTH           = 8,           // Qi, Kj width (signed)
    parameter D_K                   = 64,          // Feature dimension
    parameter DK_ADDR_WIDTH         = $clog2(D_K),
    parameter MAX_NUM_QUERIES       = 256,
    parameter IDX_ADDR_WIDTH        = $clog2(MAX_NUM_QUERIES),

    parameter PROD_WIDTH            = 16,          // Width of z_j MAC output
    parameter SUM_WIDTH             = 18,          // Width of exp sum accumulator
    parameter SOFTMAX_OUT_WIDTH     = 12           // Final softmax precision
)(
    // -------------------------------
    // Outputs
    // -------------------------------
    output logic [SOFTMAX_OUT_WIDTH-1 :0] softmax_j,   // Pass3 output
    output logic                          valid_out,   // High when output is valid
    output logic                          done,        // Asserted when all softmax outputs are generated
    output logic [DK_ADDR_WIDTH-1:0]      dk_idx,      // Index within D_K (MAC dimension)
    output logic [IDX_ADDR_WIDTH:0]       key_idx,     // Current key index during PASS1
    output logic [IDX_ADDR_WIDTH-1:0]     softmax_idx, // Current softmax index in PASS3

    // -------------------------------
    // Inputs
    // -------------------------------
    input                                  clk,
    input                                  rst_,
    input  signed [INPUT_WIDTH-1:0]        q_i,     // Qi input
    input  signed [INPUT_WIDTH-1:0]        k_j,     // Kj input
    input                                  start,
    input        [IDX_ADDR_WIDTH:0]        num_queries
);

    // =========================================================================
    // Local constants and precision configs
    // =========================================================================
    localparam ZERO               = {SUM_WIDTH{1'b0}};
    localparam EXP_FRACTION_BITS  = 11;
    localparam EXP_BITS           = EXP_FRACTION_BITS + 1;
    localparam SUM_FRACTION_BITS  = 11;
    localparam LUT_FRACTION_BITS  = 6;
    localparam RECIP_LUT_WIDTH    = 9;

    // scale_factor = sqrt(d_k)
    localparam int SQRT_DK        = $rtoi($sqrt(D_K));
    localparam SCALING_SHIFT      = $clog2(SQRT_DK);

    // =========================================================================
    // Internal signals
    // =========================================================================
    logic enable_pass1, enable_pass2, enable_pass3;
    logic done_pass1,   done_pass2,   done_pass3;
    logic done_mac;
    logic store_zj;

    logic signed [PROD_WIDTH-1:0] z_j;          // MAC running accumulation
    logic signed [PROD_WIDTH-1:0] z_max;        // Running max (PASS2)
    logic signed [PROD_WIDTH-1:0] zj_zmax;      // z_j - z_max
    logic signed [PROD_WIDTH-1:0] z_wdata;      // Data written to z-memory
    logic signed [PROD_WIDTH-1:0] z_rdata;      // Data read  from z-memory

    logic [EXP_BITS-1:0]          e_zj_zmax;    // exp(zj - zmax)
    logic [SUM_WIDTH-1:0]         sum_exp;      // Sum of exps
    logic [IDX_ADDR_WIDTH-1:0]    z_mem_addr;   // Address selector for z-memory
    logic [IDX_ADDR_WIDTH-1:0]    z_idx;        // Pass2/Pass3 index counter
    logic                         valid_out_norm;

    // =========================================================================
    // PASS1 - MAC computation over Qi and Kj
    // =========================================================================
    // Handles dk_idx stepping through 0..D_K-1
    // Handles key_idx stepping through 0..num_queries-1
    // done_pass1 asserts when PASS1 is complete
    // =========================================================================
    always_ff @(posedge clk or negedge rst_) begin
        if (!rst_) begin
            dk_idx     <= ZERO[DK_ADDR_WIDTH-1:0];
            key_idx    <= ZERO[IDX_ADDR_WIDTH-1:0];
            done_pass1 <= 1'b0;
        end
        else if (enable_pass1) begin
            if (done_mac) begin
                dk_idx <= ZERO[DK_ADDR_WIDTH-1:0];

                // Move to next key
                if (key_idx == num_queries - 1) begin
                    key_idx     <= ZERO;
                    done_pass1  <= 1'b1;
                end else begin
                    key_idx <= key_idx + 1;
                end
            end 
            else if (dk_idx < D_K - 1) begin
                dk_idx <= dk_idx + 1;
            end
        end
    end

    assign store_zj = ~done_mac;

    // =========================================================================
    // PASS2 + PASS3 Index counter
    // =========================================================================
    always_ff @(posedge clk or negedge rst_) begin
        if (!rst_) begin
            z_idx      <= ZERO;
            done_pass2 <= 1'b0;
            done_pass3 <= 1'b0;
        end
        else if (enable_pass2 && !done_pass2) begin
            // PASS2: accumulate exp(z)
            if (z_idx == num_queries - 1) begin
                z_idx      <= ZERO;
                done_pass2 <= 1'b1;
            end else begin
                z_idx <= z_idx + 1;
            end
        end
        else if (enable_pass3 && !done_pass3) begin
            // PASS3: normalization
            if (z_idx == num_queries - 1) begin
                z_idx      <= ZERO;
                done_pass3 <= 1'b1;
            end else begin
                z_idx <= z_idx + 1;
            end
        end
    end

    // =========================================================================
    // PASS3 - Output index and final done flag
    // =========================================================================
    always_ff @(posedge clk or negedge rst_) begin
        if (!rst_) begin
            softmax_idx <= ZERO;
            done        <= 1'b0;
        end
        else if (valid_out_norm) begin
            softmax_idx <= z_idx;

            if (softmax_idx == num_queries - 1)
                done <= 1'b1;
        end
    end

    // =========================================================================
    // Memory address and data-path signals
    // =========================================================================
    assign z_mem_addr = enable_pass1 ? key_idx : z_idx;

    assign zj_zmax    = z_rdata - z_max;

    // Scale z_j by sqrt(d_k) at the end of PASS1
    assign z_wdata = done_mac
                     ? $signed(z_j >>> SCALING_SHIFT)
                     : $signed(ZERO[PROD_WIDTH-1:0]);

    assign valid_out = valid_out_norm & ~done;

    // =========================================================================
    // Submodules
    // =========================================================================

    // ------------------ MAC Engine ------------------
    mac_engine #(
        .WIDTH      (INPUT_WIDTH),
        .D_K        (D_K),
        .PROD_WIDTH (PROD_WIDTH)
    ) mac_engine (
        .clk      (clk),
        .rst_     (rst_),
        .enable   (enable_pass1),
        .q_i      (q_i),
        .k_j      (k_j),
        .z_j      (z_j),
        .done_mac (done_mac)
    );

    // ------------------ Z Memory ------------------
    z_memory #(
        .PROD_WIDTH      (PROD_WIDTH),
        .MAX_NUM_QUERIES (MAX_NUM_QUERIES)
    ) z_memory (
        .clk     (clk),
        .rst_    (rst_),
        .z_wdata (z_wdata),
        .addr    (z_mem_addr),
        .rw_     (store_zj),
        .z_rdata (z_rdata)
    );

    // ------------------ Running Max (for exp shift) ------------------
    running_max #(
        .PROD_WIDTH(PROD_WIDTH)
    ) running_max (
        .clk     (clk),
        .rst_    (rst_),
        .enable  (done_mac),
        .z_in    (z_wdata),
        .max_out (z_max)
    );

    // ------------------ EXP Lookup Table ------------------
    exp_lut exp_lut (
        .input_q8_7  (zj_zmax),
        .output_q1_11(e_zj_zmax)
    );

    // ------------------ Exp Accumulator ------------------
    accumulator #(
        .SUM_WIDTH         (SUM_WIDTH),
        .EXP_FRACTION_BITS (EXP_FRACTION_BITS)
    ) accumulator (
        .sum       (sum_exp),
        .clk       (clk),
        .rst_      (rst_),
        .enable    (enable_pass2 && !done_pass2),
        .e_zj_zmax (e_zj_zmax)
    );

    // ------------------ Normalizer ------------------
    normalizer #(
        .PROD_WIDTH        (PROD_WIDTH),
        .SUM_WIDTH         (SUM_WIDTH),
        .SUM_FRACTION_BITS (SUM_FRACTION_BITS),
        .EXP_FRACTION_BITS (EXP_FRACTION_BITS),
        .LUT_FRACTION_BITS (LUT_FRACTION_BITS),
        .RECIP_LUT_WIDTH   (RECIP_LUT_WIDTH),
        .SOFTMAX_OUT_WIDTH (SOFTMAX_OUT_WIDTH)
    ) normalizer (
        .softmax_j (softmax_j),
        .valid     (valid_out_norm),
        .sum       (sum_exp),
        .e_j       (e_zj_zmax),
        .enable    (enable_pass3),
        .clk       (clk),
        .rst_      (rst_)
    );

    // ------------------ FSM ------------------
    qkt_softmax_fsm qkt_softmax_fsm (
        .enable_pass1 (enable_pass1),
        .enable_pass2 (enable_pass2),
        .enable_pass3 (enable_pass3),
        .done_pass1   (done_pass1),
        .done_pass2   (done_pass2),
        .done_pass3   (done_pass3),
        .start        (start),
        .clk          (clk),
        .rst_         (rst_)
    );

endmodule
