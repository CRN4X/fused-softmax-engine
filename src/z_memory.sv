//==========================================================================
// z_memory.sv
// -------------------------------------------------------------------------
// Description:
//   Simple synchronous single-port memory used to store the Z_j values
//   produced after MAC accumulation for each query index.
//
//   Supports:
//      • Synchronous write on clock edge
//      • Combinational (asynchronous) read when rw_ = 1
//      • Memory clearing on reset.
//
// Interface:
//      rw_ = 1 : READ  (z_rdata = mem[addr])
//      rw_ = 0 : WRITE (mem[addr] = z_wdata on next posedge clk)
//
//
// -------------------------------------------------------------------------
// Author : <your name>
// Date   : <date>
//==========================================================================

module z_memory
#(
    parameter PROD_WIDTH        = 16,                     // Width of data stored
    parameter MAX_NUM_QUERIES   = 256,                    // Memory depth
    parameter ADDR_WIDTH        = $clog2(MAX_NUM_QUERIES) // Derived address width
)
(
    output logic [PROD_WIDTH-1:0] z_rdata,   // Read data

    input                          clk,       // Clock
    input                          rst_,      // Active-low reset
    input  logic [PROD_WIDTH-1:0]  z_wdata,   // Write data
    input  logic [ADDR_WIDTH-1:0]  addr,      // Address
    input                          rw_        // Read/Write select (1=READ, 0=WRITE)
);

    //--------------------------------------------------------------------------
    // Memory declaration: MAX_NUM_QUERIES x PROD_WIDTH
    //--------------------------------------------------------------------------
    reg [PROD_WIDTH-1:0] mem [0:MAX_NUM_QUERIES-1];

    //--------------------------------------------------------------------------
    // Synchronous operations
    //   * Reset clears memory
    //   * Write occurs on posedge clk when rw_ = 0
    //--------------------------------------------------------------------------

    always @(posedge clk) begin
        if (!rst_) begin
            // Clear memory on reset (synthesizable for FPGA)
            for (int i = 0; i < MAX_NUM_QUERIES; i++)
                mem[i] <= {PROD_WIDTH{1'b0}};
        end
        else if (!rw_) begin
            // WRITE operation
            mem[addr] <= z_wdata;
        end
    end

    //--------------------------------------------------------------------------
    // Asynchronous read path
    //
    //   rw_ = 1 → valid read: z_rdata = mem[addr]
    //   rw_ = 0 → during write cycles, drive zeros
    //
    //--------------------------------------------------------------------------

    assign z_rdata = rw_ ? mem[addr] : {PROD_WIDTH{1'b0}};

endmodule
