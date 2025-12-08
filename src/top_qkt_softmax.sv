`timescale 1ns/1ps

// ============================================================================
//  Testbench for qkt_softmax
// ----------------------------------------------------------------------------
//  This testbench performs the following:
//  1. Allows user to specify whether test vectors need to be generated randomly
//     or should they be read from a txt file. 
//  2. if USE_RANDOM_VECTORS = 0, Reads real-valued Q and K matrices from files
//     - Q_float_normalized_fixed_scale.txt
//     - K_float_normalized_fixed_scale.txt
//
//     and Reads corresponding fixed-point Q0.7 binary values
//     - Q_matrix_fixed_scale.txt
//     - K_matrix_fixed_scale.txt
//
//  3. if USE_RANDOM_VECTORS = 1, Generates the real values Q and K matrices and
//     convert them to Q0.7 binary and store them to test vector input variables       
//  4. Feeds Q_i and K_j into the DUT cycle-by-cycle based on DUT's dk_idx & key_idx.
//
//  5. Collects all softmax_j outputs from the DUT for a single query (qi=0).
//
//  6. Computes a high-precision floating-point GOLDEN softmax with real number calculations.
//
//  7. Computes absolute error (MAE) and percentage error (MAPE).
//
//  8. Prints per-element comparison and overall accuracy metrics.
//
//  The testbench is designed for a one row of entire QK^T softmax computation. (Means One Q vector with Entire key Matrix)
// ============================================================================

module tb_qkt_softmax;

    // =========================================================================
    // Parameter Definitions
    // =========================================================================
    localparam INPUT_WIDTH          = 8;                        // Q0.7 format
    localparam D_K                  = 64;                       // Key dimension (Only even powers of 2 allowed)
    localparam Q_SCALE              = 2.0 ** (INPUT_WIDTH-1);   // Real → Q0.7 scale
    localparam real SQRT_DK         = $sqrt(D_K);               // √Dk normalization factor
    localparam SOFTMAX_OUT_WIDTH    = 12;                       // Final softmax precision
    localparam real SOFTMAX_SCALE   = 2.0 ** SOFTMAX_OUT_WIDTH;
    
    // =========================================================================
    // MODIFY IF NEEDED
    //      N                   - number of key vectors (num_entries input to 
    //                            the Module)    
    //      USE_RANDOM_VECTORS  - Chooses whether to generate vectors or read 
    //                            vectors from a file
    // =========================================================================   
    localparam N                    = 64;                      // Sequence length
    localparam USE_RANDOM_VECTORS   = 0;                       // 0 = read from file, 1 = random
    
    // =========================================================================
    // DUT Interface Signals
    // =========================================================================
    
    // DUT Inputs
    logic clk, rst_, start;
    logic [INPUT_WIDTH-1:0] q_i, k_j;
    logic [8:0] num_queries;

    // DUT outputs
    logic [SOFTMAX_OUT_WIDTH-1:0] softmax_j;
    logic valid_out,done;
    logic [10:0] dk_idx, key_idx, query_idx, softmax_idx;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    qkt_softmax #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .D_K(D_K),
        .MAX_NUM_QUERIES(128),
        .SOFTMAX_OUT_WIDTH(SOFTMAX_OUT_WIDTH)
    ) dut (
        .softmax_j(softmax_j),
        .valid_out(valid_out),
        .done(done),
        .dk_idx(dk_idx),
        .key_idx(key_idx),
        .softmax_idx(softmax_idx),
        .clk(clk),
        .rst_(rst_),
        .q_i(q_i),
        .k_j(k_j),
        .start(start),
        .num_queries(num_queries)
    );

    // Clock: 100 MHz (10 ns period)
    always #5 clk = ~clk;

    // ============================================================
    // TEST VECTORS & RESULTS VARIABLE DECLARATION
    // ============================================================
    integer r;
    integer fd_Q, fd_K;     // File handling variables
    
    // Q and K as real for golden model
    real Q_real[0:N-1][0:D_K-1];
    real K_real[0:N-1][0:D_K-1];

    // Quantized fixed-point versions (Q0.7, fed into DUT)
    logic signed [7:0] Q_fx[0:N-1][0:D_K-1];
    logic signed [7:0] K_fx[0:N-1][0:D_K-1];

    // Golden z-values and softmax results
    real Z_real[0:N-1];
    real softmax_gold_real [0:N-1];
    real softmax_j_out_real;
    real max_z, sum_exp;
    logic [12:0] softmax_j_out[0:N-1];
    

    // =========================================================================
    // Function : Convert real to Q0.7 signed
    // =========================================================================
    function automatic logic signed [7:0] to_q07(real x);
        real scaled;
        begin
            scaled = x * Q_SCALE;
            
            // Saturate
            if (scaled > 127) scaled = 127;
            if (scaled < -128) scaled = -128;
            
            return $rtoi(scaled);
        end
    endfunction

    // ============================================================
    // GOLDEN MODEL : SOFTMAX for a given Query index
    // ============================================================
    task compute_golden(input int qi);
        
        int j;

        // ----------------------------------------------------
        // Step 1: Compute Z_j = Q_i · K_j / √Dk
        // ----------------------------------------------------
        for (j = 0; j < N; j++) begin
            Z_real[j] = 0.0;
            for (int t = 0; t < D_K; t++)
                Z_real[j] += ((Q_real[qi][t] * K_real[j][t])/SQRT_DK);
        end

        // ----------------------------------------------------
        // Step 2: Numerical Stabilization - Find max(Z)
        // ----------------------------------------------------
        max_z = Z_real[0];
        for (j = 1; j < N; j++)
            if (Z_real[j] > max_z)
                max_z = Z_real[j];

        // ----------------------------------------------------
        // Step 3: Compute denominator sum(exp(Z_j - max_z))
        // ----------------------------------------------------
        sum_exp = 0.0;
        for (j = 0; j < N; j++)
            sum_exp += $exp(Z_real[j] - max_z);

        // ----------------------------------------------------
        // Step 4: Final Softmax = exp(Z_j - max_z)/sum_exp
        // ----------------------------------------------------
        for (j = 0; j < N; j++) begin
            softmax_gold_real[j] = $exp(Z_real[j] - max_z) / sum_exp;
        end
    endtask

    // =========================================================================
    // Compare DUT Output vs Golden Output
    // =========================================================================
    task automatic check_results(input int qi);
        int j = 0;
        real error[0:N-1], error_perc[0:N-1];
        real error_sum, error_perc_sum;
        
        // ------------------------------------------------------------
        // Print element-wise comparison
        // ------------------------------------------------------------
        while (j < N) begin
            softmax_j_out_real    = softmax_j_out[j] / SOFTMAX_SCALE;
            error[j] = softmax_j_out_real - softmax_gold_real[j];
            error[j] = ( error[j] < 0.0 ) ? -error[j] : error[j];
            error_perc[j] = (error[j]*100.0)/softmax_gold_real[j];
            
            $display("DUT=%8f GOLD=%8f, Error = %8f, Error Percentage = %0.2f %%",
                                softmax_j_out_real, softmax_gold_real[j], error[j], error_perc[j]);
            j++;
        end
        
        // ------------------------------------------------------------
        // Compute MAE and MAPE
        // ------------------------------------------------------------
        error_sum = 0.0;
        error_perc_sum = 0.0;
        foreach(error[i]) error_sum += error[i];
        foreach(error_perc[i]) error_perc_sum += error_perc[i];
        
        $display("MAE=%8f MAPE=%0.2f %%", error_sum/N, (error_perc_sum)/N);
    endtask

    // ============================================================
    // MAIN TEST
    // ============================================================
    initial begin
        clk = 0;
        rst_ = 0;
        start = 0;
        num_queries = N;

        
        if (!USE_RANDOM_VECTORS) 
        begin : READ_FROM_FILES
            // ------------------------------------------------------------
            // 1. Load real Q, K values for golden model
            // ------------------------------------------------------------
            fd_Q = $fopen("Q_float_normalized_fixed_scale.txt", "r");
            fd_K = $fopen("K_float_normalized_fixed_scale.txt", "r");
            
            for (int i = 0; i < N; i++) begin
                for (int t = 0; t < D_K; t++) begin
                    $fscanf(fd_Q, "%f", Q_real[i][t]);
                    $fscanf(fd_K, "%f", K_real[i][t]);
                end
            end
            
            $fclose(fd_Q);
            $fclose(fd_K);
            
            // ------------------------------------------------------------
            // 2. Load Q0.7 binary values (fed into DUT)
            // ------------------------------------------------------------
            fd_Q = $fopen("Q_matrix_fixed_scale.txt", "r");
            fd_K = $fopen("K_matrix_fixed_scale.txt", "r");
            for (int i = 0; i < N; i++) begin
                for (int t = 0; t < D_K; t++) begin
                    $fscanf(fd_Q, "%b", Q_fx[i][t]);
                    $fscanf(fd_K, "%b", K_fx[i][t]);
                end
            end
            $fclose(fd_Q);
            $fclose(fd_K);
        end
        else 
        begin : RANDOM_GENERATION
            // ---------------------------------------------------------
            // MODE 2: Generate random real Q,K in [-1,1) 
            // and generate fixed-point Q0.7 versions
            // ---------------------------------------------------------
            $display("INFO: Generating RANDOM Q and K values...");
    
            for (int i = 0; i < N; i++) begin
                for (int t = 0; t < D_K; t++) begin
    
                    // Uniform random real in [-1, 1)
                    r = $urandom_range(-1000, 1000);
                    Q_real[i][t] = r * 0.001;
    
                    r = $urandom_range(-1000, 1000);
                    K_real[i][t] = r * 0.001;
    
                    // Quantize to Q0.7
                    Q_fx[i][t] = to_q07(Q_real[i][t]);
                    K_fx[i][t] = to_q07(K_real[i][t]);
                end
            end
            $display("INFO: Random Q and K generation completed.");
        end
    
        // ------------------------------------------------------------
        // 3. Reset and Start DUT
        // ------------------------------------------------------------
        repeat(5) @(negedge clk);
        rst_ = 1;
        start = 1;
        @(negedge clk);
        start = 0;
        
        // ------------------------------------------------------------
        // 4. Capture DUT outputs until valid_out deasserts
        // ------------------------------------------------------------
        wait (valid_out === 1'b1);
        @(negedge clk);
        while (valid_out === 1'b1)
        begin
            softmax_j_out[softmax_idx] = softmax_j;
            @(negedge clk);
        end
        
        // ------------------------------------------------------------
        // 5. Wait for DUT completion signal
        // ------------------------------------------------------------
        wait (done === 1'b1);  
        
        // ------------------------------------------------------------
        // 6. Run golden model and compare
        // ------------------------------------------------------------      
        compute_golden(0);
        check_results(0);
        repeat(20) @(negedge clk);
        $finish;     
    end
    
    // Feed the DUT using its internal indexing
    assign q_i = Q_fx[0][dk_idx];
    assign k_j = K_fx[key_idx][dk_idx];

endmodule
