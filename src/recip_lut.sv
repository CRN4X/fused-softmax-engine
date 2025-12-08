
// ===========================================================
// Reciprocal Lookup Table with Mantissa-to-Index Conversion
// -----------------------------------------------------------
// Function : Outputs 1/m for m ∈ [0.5, 1.0)
// Input    : Actual mantissa value m (in fixed-point format)
// Output   : 9-bit Q1.8 reciprocal value
// ===========================================================

module recip_lut (
    input  logic [6:0]  m_value,      // Q0.7 mantissa value (0.5 ≤ m < 1.0)
    output logic [8:0] lut_output    // Q1.8 output (1/m values)
);

    logic [5:0] m_index;  // Internal index for LUT

    // Convert mantissa value to LUT index
    always_comb begin
        // m_value is in Q0.7 format, range [0.5, 1.0)
        // 0.5 in Q0.7 = 7'b1000000 = 8'h40 = 64
        // 1.0 in Q1.7 = 8'b100000000 = 8'h80 = 128 (not inclusive)
        
        // Map m_value [64, 127] to index [0, 63]
        if (m_value >= 7'h40) 
        begin
            m_index = m_value[5:0];
        end 
        else 
        begin
            m_index = 6'b000000;  // Default to index 0 (m = 0.5)
        end
    end
    
    // Reciprocal LUT with Q1.8 output 
    always_comb begin
        case (m_index)
 
            6'b000000: lut_output = 9'h1FF; // 1/0.500000 = 1.996093
            6'b000001: lut_output = 9'h1F8; // 1/0.507812 = 1.969231
            6'b000010: lut_output = 9'h1F0; // 1/0.515625 = 1.939394
            6'b000011: lut_output = 9'h1E9; // 1/0.523438 = 1.910448
            6'b000100: lut_output = 9'h1E2; // 1/0.531250 = 1.882353
            6'b000101: lut_output = 9'h1DB; // 1/0.539062 = 1.855072
            6'b000110: lut_output = 9'h1D4; // 1/0.546875 = 1.828571
            6'b000111: lut_output = 9'h1CE; // 1/0.554688 = 1.802817
            6'b001000: lut_output = 9'h1C7; // 1/0.562500 = 1.777778
            6'b001001: lut_output = 9'h1C1; // 1/0.570312 = 1.753425
            6'b001010: lut_output = 9'h1BB; // 1/0.578125 = 1.729730
            6'b001011: lut_output = 9'h1B5; // 1/0.585938 = 1.706667
            6'b001100: lut_output = 9'h1AF; // 1/0.593750 = 1.684211
            6'b001101: lut_output = 9'h1AA; // 1/0.601562 = 1.662338
            6'b001110: lut_output = 9'h1A4; // 1/0.609375 = 1.641026
            6'b001111: lut_output = 9'h19F; // 1/0.617188 = 1.620253
            6'b010000: lut_output = 9'h19A; // 1/0.625000 = 1.600000
            6'b010001: lut_output = 9'h195; // 1/0.632812 = 1.580247
            6'b010010: lut_output = 9'h190; // 1/0.640625 = 1.560976
            6'b010011: lut_output = 9'h18B; // 1/0.648438 = 1.542169
            6'b010100: lut_output = 9'h186; // 1/0.656250 = 1.523810
            6'b010101: lut_output = 9'h182; // 1/0.664062 = 1.505882
            6'b010110: lut_output = 9'h17D; // 1/0.671875 = 1.488372
            6'b010111: lut_output = 9'h179; // 1/0.679688 = 1.471264
            6'b011000: lut_output = 9'h174; // 1/0.687500 = 1.454545
            6'b011001: lut_output = 9'h170; // 1/0.695312 = 1.438202
            6'b011010: lut_output = 9'h16C; // 1/0.703125 = 1.422222
            6'b011011: lut_output = 9'h168; // 1/0.710938 = 1.406593
            6'b011100: lut_output = 9'h164; // 1/0.718750 = 1.391304
            6'b011101: lut_output = 9'h160; // 1/0.726562 = 1.376344
            6'b011110: lut_output = 9'h15D; // 1/0.734375 = 1.361702
            6'b011111: lut_output = 9'h159; // 1/0.742188 = 1.347368
            6'b100000: lut_output = 9'h155; // 1/0.750000 = 1.333333
            6'b100001: lut_output = 9'h152; // 1/0.757812 = 1.319588
            6'b100010: lut_output = 9'h14E; // 1/0.765625 = 1.306122
            6'b100011: lut_output = 9'h14B; // 1/0.773438 = 1.292929
            6'b100100: lut_output = 9'h148; // 1/0.781250 = 1.280000
            6'b100101: lut_output = 9'h144; // 1/0.789062 = 1.267327
            6'b100110: lut_output = 9'h141; // 1/0.796875 = 1.254902
            6'b100111: lut_output = 9'h13E; // 1/0.804688 = 1.242718
            6'b101000: lut_output = 9'h13B; // 1/0.812500 = 1.230769
            6'b101001: lut_output = 9'h138; // 1/0.820312 = 1.219048
            6'b101010: lut_output = 9'h135; // 1/0.828125 = 1.207547
            6'b101011: lut_output = 9'h132; // 1/0.835938 = 1.196262
            6'b101100: lut_output = 9'h12F; // 1/0.843750 = 1.185185
            6'b101101: lut_output = 9'h12D; // 1/0.851562 = 1.174312
            6'b101110: lut_output = 9'h12A; // 1/0.859375 = 1.163636
            6'b101111: lut_output = 9'h127; // 1/0.867188 = 1.153153
            6'b110000: lut_output = 9'h125; // 1/0.875000 = 1.142857
            6'b110001: lut_output = 9'h122; // 1/0.882812 = 1.132743
            6'b110010: lut_output = 9'h11F; // 1/0.890625 = 1.122807
            6'b110011: lut_output = 9'h11D; // 1/0.898438 = 1.113043
            6'b110100: lut_output = 9'h11A; // 1/0.906250 = 1.103448
            6'b110101: lut_output = 9'h118; // 1/0.914062 = 1.094017
            6'b110110: lut_output = 9'h116; // 1/0.921875 = 1.084746
            6'b110111: lut_output = 9'h113; // 1/0.929688 = 1.075630
            6'b111000: lut_output = 9'h111; // 1/0.937500 = 1.066667
            6'b111001: lut_output = 9'h10F; // 1/0.945312 = 1.057851
            6'b111010: lut_output = 9'h10D; // 1/0.953125 = 1.049180
            6'b111011: lut_output = 9'h10A; // 1/0.960938 = 1.040650
            6'b111100: lut_output = 9'h108; // 1/0.968750 = 1.032258
            6'b111101: lut_output = 9'h106; // 1/0.976562 = 1.024000
            6'b111110: lut_output = 9'h104; // 1/0.984375 = 1.015873
            6'b111111: lut_output = 9'h102; // 1/0.992188 = 1.007874
            default  : lut_output = 9'h1FF; // 1/0.500000 = 1.996093
        endcase
    end
endmodule
