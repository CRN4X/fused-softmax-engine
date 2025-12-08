/*===============================================================
 *  Module      : accumulator
 *  Description : Accumulates exponent-scaled values (e_zj_zmax) 
 *                across cycles to produce the final softmax
 *                denominator Σ exp(z_j - z_max).
 *
 *  Parameters  :
 *      SUM_WIDTH           - Width of running sum output
 *      EXP_FRACTION_BITS   - Number of fractional bits in exponent format
 *      EXP_BITS            - Total width of exponent input (1 sign + fraction)
 *
 *  Inputs      :
 *      clk                 - System clock
 *      rst_                - Active-low synchronous reset
 *      enable              - Accumulate enable signal
 *      e_zj_zmax           - exp(z_j - z_max) value in fixed-point format
 *
 *  Outputs     :
 *      sum                 - Running accumulated output Σ exp(z_j - z_max)
 *
 *
 *===============================================================*/

module accumulator
#(
    parameter SUM_WIDTH  = 18,
    parameter EXP_FRACTION_BITS = 11,
    parameter EXP_BITS = EXP_FRACTION_BITS + 1
)
(
    output logic    [SUM_WIDTH-1:0]        sum,

    input                                   clk,
    input                                   rst_,
    input                                   enable,
    input  logic    [EXP_BITS - 1 :0]       e_zj_zmax
 );
    
     // Local zero constant matching SUM_WIDTH
    localparam ZERO = {SUM_WIDTH{1'b0}};
        
    // -------------------------------------------------------------
    // Running accumulator
    // On reset:     sum = 0
    // On enable:    sum = sum + e_zj_zmax
    // -------------------------------------------------------------
    always @ ( posedge clk or negedge rst_ )
    begin
        if ( !rst_ )
        begin
            sum     <= ZERO;                // Initialize accumulator
        end
        else if ( enable )
        begin
            sum     <= sum + e_zj_zmax;     // Accumulate exponent values
        end
    end    
endmodule
