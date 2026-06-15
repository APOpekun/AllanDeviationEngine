`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Houston - Clear Lake
// Engineer: Alexander P. Opekun
// 
// Create Date: 06/11/2026 03:00:03 PM
// Design Name: Streaming Allan Deviation Engine 
// Module Name: Allan Deviation Engine
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: a collection of modules that are paramterized to tune the allan engine to desired specificaitons 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Differencer
    #(parameter DATA_WIDTH = 16,
      parameter MEMORY_REGS = 64,
      parameter offset = 1,
      localparam int  ADDR_WIDTH = ceil(log(ADDR_WIDTH)/log(2))
    )
    (
    input clk,
    input rst,
    input logic [DATA_WIDTH-1:0]  inData [0:MEMORY_REGS-1],
    input logic                  inValid [0:MEMORY_REGS-1],
    output logic [DATA_WIDTH-1:0]  outData [0:MEMORY_REGS-1-offset],
    output logic                  outValid [0:MEMORY_REGS-1-offset]
    );
    generate
        for (genvar src_A = 0; src_A < MEMORY_REGS-offset; src_A++) begin : Difference
            // Compute
            logic [ADDR_WIDTH-1:0] src_B;
            always_comb begin
                src_B = src_A + offset;
            end
            always_ff @(posedge clk)begin
                if(rst)begin
                    outData[src_A] <= '0;
                    outValid[src_A]  <= '0;
                end
                else begin
                    outData[src_A]  <=  inData[src_A] -  inData[src_B];
                    outValid[src_A]  <= inValid[src_A] & inValid[src_B];
                end
            end
        end
    endgenerate
endmodule
module squarer
    #(parameter DATA_WIDTH = 16,
      parameter MEMORY_REGS = 64
    )
    (
    input clk,
    input rst,
    input logic [DATA_WIDTH-1:0]  inData [0:MEMORY_REGS-1],
    input logic                  inValid [0:MEMORY_REGS-1],
    output logic [2*DATA_WIDTH-1:0]  outData [0:MEMORY_REGS-1],
    output logic                  outValid [0:MEMORY_REGS-1]
    );
    generate
        for (genvar src = 0; src < MEMORY_REGS; src++) begin : square
            // Compute
            always_ff @(posedge clk)begin
                if(rst)begin
                    outData[src] <= '0;
                    outValid[src]  <= '0;
                end else begin
                    outData[src]  <=  inData[src] *  inData[src];
                    outValid[src]  <= inValid[src];
                end
            end
            
        end
    endgenerate
endmodule

////cascade accumulator 
//module accumulator
//    #(parameter DATA_WIDTH = 16,
//      parameter MEMORY_REGS = 64,
//      localparam ACC_WIDTH = DATA_WIDTH + $clog2(MEMORY_REGS)
//    )
//    (
//    input  logic                    clk,
//    input  logic                    rst,
//    input  logic [DATA_WIDTH-1:0]   inData [0:MEMORY_REGS-1],
//    input  logic                    inValid [0:MEMORY_REGS-1],
//    output logic [DATA_WIDTH-1:0]   outData,
//    output logic                    outValid
//    );
//    logic [0:MEMORY_REGS-1] valid_array;
//    logic [ACC_WIDTH-1:0] sum_next;
//    logic                 valid_next;


//    // ------------------------------
//    // Combinational reduction logic
//    // ------------------------------
//    always_comb begin
//        sum_next   = '0;
//        for (int i = 0; i < MEMORY_REGS; i++) begin
//            sum_next   += inData[i];
//        end
//    end
//    always_comb begin
//        for (int i = 0; i < MEMORY_REGS; i++) begin
//            valid_array[i] <= inValid[i];
//        end
//        valid_next = &valid_array;
//    end
//    // ------------------------------
//    // Registered output
//    // ------------------------------
//    always_ff @(posedge clk) begin
//        if (rst) begin
//            outData  <= '0;
//            outValid <= 1'b0;
//        end else begin
//            outData  <= sum_next;
//            outValid <= valid_next;
//        end
//    end

//endmodule

////adder_tree accumulator with Valid Gap Detection 
module streaming_accumulator #(
    parameter int DATA_WIDTH  = 16,                     // width of each input sample
    parameter int MEMORY_REGS = 64,                     // number of parallel samples
    parameter int ACC_WIDTH   = DATA_WIDTH + $clog2(MEMORY_REGS) // full-precision sum width
)(
    input  logic                      clk,
    input  logic                      rst,

    // Parallel data from serial-to-parallel front-end
    input  logic [DATA_WIDTH-1:0]     inData  [MEMORY_REGS],
    input  logic                      inValid [MEMORY_REGS],

    output logic [ACC_WIDTH-1:0]      outData,
    output logic                      outValid
);
    // -------------------------------------------------------------------------
    // Instantiate gap detector
    // -------------------------------------------------------------------------
    logic gap;
    logic any_valid;
    logic [DATA_WIDTH-1:0] maskedData [MEMORY_REGS];

    gap_detector #(
        .MEMORY_REGS(MEMORY_REGS)
    ) gd_inst (
        .inValid(inValid),
        .gap(gap),
        .any_valid(any_valid)
    );
    
    // -------------------------------------------------------------------------
    // Tree geometry: round MEMORY_REGS up to next power-of-two for clean pairing
    // -------------------------------------------------------------------------
    localparam int P2     = 1 << $clog2(MEMORY_REGS);  // next power of 2
    localparam int STAGES = $clog2(P2);                // number of adder stages

    // -------------------------------------------------------------------------
    // Pipeline storage for the adder tree
    // stage_data[s][n] = node n at pipeline stage s
    // stage_valid[s]   = validity bit for stage s
    // -------------------------------------------------------------------------
    logic [ACC_WIDTH-1:0] stage_data [STAGES+1][P2];
    logic                 stage_valid[STAGES+1];

    // -------------------------------------------------------------------------
    // Mask invalid entries
    // -------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < MEMORY_REGS; i++) begin
            maskedData[i] = inValid[i] ? inData[i] : '0;
        end
    end

    // -------------------------------------------------------------------------
    // SECTION 2 - PIPELINE STAGE 0
    //
    // Responsibilities:
    //   • Mask invalid entries (convert them to zero)
    //   • Zero out everything if a gap is detected
    //   • Register the first stage of the tree
    //   • stage_valid[0] = (any_valid && !gap)
    //
    // Note:
    //   Data is widened to ACC_WIDTH here so the tree never overflows.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            stage_valid[0] <= 1'b0;

            for (int i = 0; i < P2; i++)
                stage_data[0][i] <= '0;
        end
        else begin
            // Valid only if at least one valid bit AND no gap
            stage_valid[0] <= (any_valid && !gap);

            for (int i = 0; i < P2; i++) begin
                if (!gap && i < MEMORY_REGS && inValid[i]) begin
                    // widen DATA_WIDTH → ACC_WIDTH
                    stage_data[0][i] <= {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, maskedData[i]};
                end
                else begin
                    stage_data[0][i] <= '0;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // SECTION 3 - PIPELINED ADDER TREE
    //
    // Each stage halves the number of nodes:
    //   P2 → P2/2 → P2/4 → ... → 1
    //
    // Each stage is registered:
    //   • stage_data[s+1][n] = stage_data[s][2n] + stage_data[s][2n+1]
    //   • stage_valid[s+1]   = stage_valid[s]
    //
    // Latency: STAGES cycles
    // Throughput: 1 result per cycle
    // -------------------------------------------------------------------------
    for (genvar s = 0; s < STAGES; s++) begin : TREE
        localparam int NODES = P2 >> (s+1);

        always_ff @(posedge clk) begin
            if (rst) begin
                stage_valid[s+1] <= 1'b0;

                for (int n = 0; n < NODES; n++)
                    stage_data[s+1][n] <= '0;
            end
            else begin
                stage_valid[s+1] <= stage_valid[s];

                for (int n = 0; n < NODES; n++) begin
                    // balanced binary tree addition
                    stage_data[s+1][n] <= stage_data[s][2*n] + stage_data[s][2*n+1];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // SECTION 4 - FINAL OUTPUT
    //
    // The last stage contains exactly one node: stage_data[STAGES][0]
    // stage_valid[STAGES] indicates whether the sum is meaningful.
    // -------------------------------------------------------------------------
    assign outData  = stage_data[STAGES][0];
    assign outValid = stage_valid[STAGES];
endmodule

module gap_detector #(
    parameter int MEMORY_REGS = 64
)(
    input  logic                  inValid [MEMORY_REGS],

    output logic                  gap,         // 1 → invalid pattern detected
    output logic                  any_valid   // 1 → at least one valid entry
);
    // -------------------------------------------------------------------------
    // Detect forbidden 1-0-1 pattern
    //
    // Allowed:
    //   1111100000  (prefix)
    //   0000011111  (suffix)
    //
    // Forbidden:
    //   any 1 0 1 pattern
    //
    // Implementation:
    //   seen_one            = we have encountered a '1'
    //   seen_zero_after_one = we saw a '0' after seeing a '1'
    //   if we later see a '1' while seen_zero_after_one == 1 → GAP
    // -------------------------------------------------------------------------
    always_comb begin
        automatic logic seen_one            = 1'b0;
        automatic logic seen_zero_after_one = 1'b0;

        gap       = 1'b0;
        any_valid = 1'b0;

        for (int i = 0; i < MEMORY_REGS; i++) begin
            if (inValid[i]) begin
                any_valid = 1'b1;

                if (seen_zero_after_one)
                    gap = 1'b1;     // found 1 after a 0 after a 1 → invalid

                seen_one = 1'b1;
            end
            else begin
                if (seen_one)
                    seen_zero_after_one = 1'b1;
            end
        end
    end
endmodule


// Differencer 
// difference of taus
// squarer
// accumulator
// divider
// rooter