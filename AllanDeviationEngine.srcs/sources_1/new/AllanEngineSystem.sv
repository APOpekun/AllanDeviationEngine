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
module main
    (
        input  logic                         clk, //Clock
        input  logic                         rst, // reset Active High
        input  logic                          we, // Write Enable
        input  logic [15:0]  SeqData, //Feeding 1 number at a time
        output logic [75:37] AllanVariance,
        output logic                       valid
    );
    logic [75:0] Variance;
    AllanDeviationEngine #
    (
        .DATA_WIDTH(16),
        .MEMORY_REGS(64),
        .offset(4)
    )
    (
        .clk(clk),
        .rst(rst),
        .we(we),
        .SeqData(SeqData),
        .AllanVariance(Variance),//Q39.37 -> Q39
        .valid(valid)
    );
     always_comb AllanVariance = Variance[75:37];
endmodule
//Proabaly should add a data clock to shift in the data
//just pretend the data arrives at clockrate
module AllanDeviationEngine
    #(
        parameter DATA_WIDTH = 16,
        parameter MEMORY_REGS = 64,
        parameter offset = 4
    )(
        input  logic                         clk, //Clock
        input  logic                         rst, // reset Active High
        input  logic                          we, // Write Enable
        input  logic [(DATA_WIDTH-1):0]  SeqData, //Feeding 1 number at a time
        output logic [2*((2*DATA_WIDTH) + $clog2(MEMORY_REGS))-1:0] AllanVariance,
        output logic                       valid
    );
    logic [DATA_WIDTH-1:0]   MemoryData [0:MEMORY_REGS-1+offset];
    logic                   MemoryValid [0:MEMORY_REGS-1+offset];

    logic [DATA_WIDTH-1:0]   DiffData [0:MEMORY_REGS-1];
    logic                     DiffValid [0:MEMORY_REGS-1];
    logic [2*DATA_WIDTH-1:0]    SqrData [0:MEMORY_REGS-1];
    logic                      SqrValid [0:MEMORY_REGS-1];
    logic [2*DATA_WIDTH-1:0]    gapData [0:MEMORY_REGS-1];
    logic                      gapValid [0:MEMORY_REGS-1];
    logic gap, any_valid;
    logic [(2*DATA_WIDTH) + $clog2(MEMORY_REGS)-1:0] recip_out,accumData;
    logic accumValid,recipValid;
    logic [$clog2(MEMORY_REGS+1)-1:0]    out_count;
    //Stage 1
    RingMemorySystem #(
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_REGS(MEMORY_REGS+offset)
    )u_RingMemSys(
        .clk(clk),
        .rst(rst),
        .we(we),
        .SeqData(SeqData),
        .outData(MemoryData),
        .outValid(MemoryValid)
    );
    //Stage 2
    Differencer #(
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_REGS(MEMORY_REGS+offset),
        .offset(offset)
    )u_Diff(
        .clk(clk),
        .rst(rst),
        .inData  ( MemoryData),
        .inValid ( MemoryValid),
        .outData ( DiffData),
        .outValid(DiffValid)
    );
    //Stage 3
    Squarer #(
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_REGS(MEMORY_REGS)
    )u_Sqr(
        .clk(clk),
        .rst(rst),
        .inData  ( DiffData),
        .inValid ( DiffValid),
        .outData(SqrData),//2*DATA_WIDTH
        .outValid(SqrValid)
    );
    //Stage 4
    PopcountTree#(.MEMORY_REGS(MEMORY_REGS)// uses 6 ccs
    ) u_ValidCounter(
        .clk(clk),
        .rst(rst),
        .inValid(SqrValid),
        .out_count(out_count) ////[Synth 8-689] width (1) of port connection 'out_count' does not match port width (7) of module 'PopcountTree' ["C:/Users/apope/Documents/VivadoProjects/AllanDeviationEngine/AllanDeviationEngine.srcs/sources_1/new/AllanEngineSystem.sv":89]
    );
    
    gap_detector #(
        .DATA_WIDTH(2*DATA_WIDTH),
        .MEMORY_REGS(MEMORY_REGS)
    ) u_GapDet (
        .clk(clk),
        .rst(rst),
        .inData  ( SqrData),
        .inValid(SqrValid),
        .outData ( gapData),
        .outValid( gapValid),
        
        .gap(gap),
        .any_valid(any_valid)
    );
    //Stage 5
    ReciprocalLUT #(
        .MEMORY_REGS(MEMORY_REGS),
        .OUT_WIDTH((2*DATA_WIDTH) + $clog2(MEMORY_REGS))
    )u_RecipLUT(
        .clk(clk),
        .rst(rst),
        .N_valid(out_count),
        .recip_out(recip_out),
        .outValid(recipValid)
    );
    //(2*DATA_WIDTH) + $clog2(MEMORY_REGS) 
    Streaming_Accumulator #(
        .DATA_WIDTH(2*DATA_WIDTH),
        .MEMORY_REGS(MEMORY_REGS)
    )u_StrAcc(
        .clk(clk),
        .rst(rst),
        .gap(gap),
        .any_valid(any_valid),
        .inData  ( gapData),
        .inValid ( gapValid),
        .outData ( accumData),
        .outValid( accumValid)
    );
    Multiplier #(
    .IN_A_WIDTH((2*DATA_WIDTH) + $clog2(MEMORY_REGS)),
    .IN_B_WIDTH((2*DATA_WIDTH) + $clog2(MEMORY_REGS))
    ) u_Multiplier (
    .clk(clk),
    .rst(rst),
    .inValid((accumValid&recipValid)),
    .outValid(valid),
    .A(recip_out),
    .B(accumData),
    .P(AllanVariance) //[2*(2*DATA_WIDTH) + $clog2(MEMORY_REGS)-1:0]
    );
    
//Accumulator:   Q38.0
//Reciprocal:    Q1.37
//--------------------------------
//Product:       Q39.37   (76 bits total)


endmodule 

module RegBank 
    #(
        parameter WIDTH = 16
    )(
        input  logic              clk,
        input  logic              rst,
        input  logic [WIDTH-1:0] d,
        output logic [WIDTH-1:0] q
    );
    always_ff @(posedge clk) begin
        if (rst)
            q <= '0;
        else
            q <= d;
    end
endmodule

module BufferN #(
    parameter int WIDTH = 1,
    parameter int DEPTH = 4        // number of pipeline stages
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [WIDTH-1:0]      in_bits,
    output logic [WIDTH-1:0]      out_bits
);

    // DEPTH pipeline registers
    logic [WIDTH-1:0] stage [0:DEPTH-1];

    genvar s;
    generate
        for (s = 0; s < DEPTH; s++) begin : PIPE
            RegBank #(.WIDTH(WIDTH)) reg_stage (
                .clk(clk),
                .rst(rst),
                .d( (s == 0) ? in_bits : stage[s-1] ),
                .q( stage[s] )
            );
        end
    endgenerate

    assign out_bits = stage[DEPTH-1];

endmodule

module Differencer
    #(parameter DATA_WIDTH = 16,
      parameter MEMORY_REGS = 64,
      parameter offset = 4,
      localparam int  ADDR_WIDTH = $clog2(MEMORY_REGS)
      
    )
    (
    input clk,
    input rst,
    input logic  [DATA_WIDTH-1:0]   inData [0:MEMORY_REGS-1],
    input   logic                  inValid [0:MEMORY_REGS-1],
    output logic [DATA_WIDTH-1:0]  outData [0:MEMORY_REGS-1-offset],
    output logic                  outValid [0:MEMORY_REGS-1-offset]
    );
    logic [DATA_WIDTH-1:0]  diffData [0:MEMORY_REGS-1-offset];
    logic                  diffValid [0:MEMORY_REGS-1-offset];
    generate
        for (genvar src_A = 0; src_A < MEMORY_REGS-offset; src_A++) begin : Difference
            // Compute
            int src_B = src_A + offset;
            RegBank #(.WIDTH(1+DATA_WIDTH)) regValidData (
                .clk(clk),
                .rst(rst),
                .d({inValid[src_A] & inValid[src_B],inData[src_A] - inData[src_B]}),
                .q({outValid[src_A],outData[src_A]})
            );
        end
    endgenerate
endmodule
module Multiplier #(
    parameter int IN_A_WIDTH   = 32,     // Q1.31
    parameter int IN_B_WIDTH   = 32,     // Q1.31
    localparam int OUT_WIDTH =  IN_A_WIDTH + IN_B_WIDTH
    )(
    input  logic                   clk,
    input  logic                   rst,
    input  logic                inValid,
    output logic                outValid,
    input  logic [IN_A_WIDTH-1:0]  A,
    input  logic [IN_B_WIDTH-1:0]  B,
    output logic [OUT_WIDTH-1:0]   P
    );

    logic [OUT_WIDTH-1:0] product;

    always_comb begin
        product = A * B;
    end

    RegBank #(.WIDTH(1+OUT_WIDTH)) reg_out (
        .clk(clk),
        .rst(rst),
        .d({inValid,product}),
        .q({outValid,P})
    );
endmodule
module Squarer
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
        Multiplier #(
            .IN_A_WIDTH(DATA_WIDTH),
            .IN_B_WIDTH(DATA_WIDTH)
        ) u_Multiplier (
            .clk(clk),
            .rst(rst),
            .inValid(inValid[src]),
            .outValid(outValid[src]),
            .A(inData[src]),
            .B(inData[src]),
            .P(outData[src]) //2*DATA_WIDTH
        );
    end
    endgenerate
endmodule

////adder_tree accumulator
module Streaming_Accumulator #(
    parameter int DATA_WIDTH  = 16,                     // width of each input sample
    parameter int MEMORY_REGS = 64,                     // number of parallel samples
    localparam int ACC_WIDTH   = DATA_WIDTH + $clog2(MEMORY_REGS) // full-precision sum width
)(
    input  logic                      clk,
    input  logic                      rst,

    // Parallel data from serial-to-parallel front-end
    input  logic [DATA_WIDTH-1:0]     inData  [MEMORY_REGS],
    input  logic                      inValid [MEMORY_REGS],
    input  logic                      gap,
    input  logic                      any_valid,
    output logic [ACC_WIDTH-1:0]      outData,
    output logic                      outValid
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
    logic [DATA_WIDTH-1:0] maskedData [MEMORY_REGS];
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
    // ---------------------------
    // Stage 0 combinational logic
    // ---------------------------
    logic                 stage_valid_d0;
    logic [ACC_WIDTH-1:0] stage_data_d0 [P2];
    always_comb begin
        // Valid only if at least one valid bit AND no gap
        stage_valid_d0 <= (any_valid && !gap);

        for (int i = 0; i < P2; i++) begin
            if (!gap && i < MEMORY_REGS && inValid[i]) begin
                // widen DATA_WIDTH → ACC_WIDTH
                stage_data_d0[i] <= {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, maskedData[i]};
            end
            else begin
                stage_data_d0[i] <= '0;
            end
        end
    end
            
    // ---------------------------
    // Stage 0 registers (RegBank)
    // ---------------------------
    RegBank #(.WIDTH(1)) reg_valid_0 (
        .clk(clk),
        .rst(rst),
        .d(stage_valid_d0),
        .q(stage_valid[0])
    );
    
    for (genvar i = 0; i < P2; i++) begin : REG_STAGE0
        RegBank #(.WIDTH(ACC_WIDTH)) reg_data_0 (
            .clk(clk),
            .rst(rst),
            .d(stage_data_d0[i]),
            .q(stage_data[0][i])
        );
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
        logic                 stage_valid_d;
        logic [ACC_WIDTH-1:0] stage_data_d [NODES];
        
        always_comb begin
            // valid just propagates
            stage_valid_d = stage_valid[s];
        
            // compute next stage nodes
            for (int n = 0; n < NODES; n++)
                stage_data_d[n] = stage_data[s][2*n] + stage_data[s][2*n+1];
        end
        RegBank #(.WIDTH(1)) reg_valid (
            .clk(clk),
            .rst(rst),
            .d(stage_valid_d),
            .q(stage_valid[s+1])
        );
        for (genvar n = 0; n < NODES; n++) begin : REG_STAGE
            RegBank #(.WIDTH(ACC_WIDTH)) reg_data (
                .clk(clk),
                .rst(rst),
                .d(stage_data_d[n]),
                .q(stage_data[s+1][n])
            );
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
    parameter int DATA_WIDTH  = 16,                     // width of each input sample
    parameter int MEMORY_REGS = 64                     // number of parallel samples
)(
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0]  inData [0:MEMORY_REGS-1],
    input logic                  inValid [0:MEMORY_REGS-1],
    output logic [DATA_WIDTH-1:0]  outData [0:MEMORY_REGS-1],
    output logic                  outValid [0:MEMORY_REGS-1],

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
    // detect the 1-0 and 0-1 threshold
    // this can detect the 1-0-1 gap
    // and will return 1 if a gap is found
    // -------------------------------------------------------------------------

    logic [0:MEMORY_REGS-1] inValid_vector,inValid_vector_reg;
    
    logic [0:MEMORY_REGS-2] pattern_10_vector,pattern_10_vector_reg,pattern_01_vector,pattern_01_vector_reg;
    logic pattern_10_det,pattern_01_det;
    always_comb begin
        for (int i = 0; i < MEMORY_REGS; i++) begin
            inValid_vector[i] =  inValid[i];
        end
        for (int i = 0; i < MEMORY_REGS-1; i++) begin
            pattern_10_vector[i] =  inValid_vector[i] && !inValid_vector[i+1];
            pattern_01_vector[i] = !inValid_vector[i] &&  inValid_vector[i+1];
        end
        
    end
    RegBank #(.WIDTH(MEMORY_REGS-1)) reg_10vec (
                .clk(clk),
                .rst(rst),
                .d(pattern_10_vector),
                .q(pattern_10_vector_reg)
            );
    RegBank #(.WIDTH(MEMORY_REGS-1)) reg_01vec (
                .clk(clk),
                .rst(rst),
                .d(pattern_01_vector),
                .q(pattern_01_vector_reg)
            );
    RegBank #(.WIDTH(MEMORY_REGS)) reg_inValid_vec (
                .clk(clk),
                .rst(rst),
                .d(inValid_vector),
                .q(inValid_vector_reg)
            );    
    assign pattern_10_det = |pattern_10_vector_reg;
    assign pattern_01_det = |pattern_01_vector_reg;

     BufferN #(.WIDTH(2),.DEPTH(5)) FlagBuffer (
        .clk(clk),
        .rst(rst),
        .in_bits({pattern_10_det && pattern_01_det,|inValid_vector_reg}),
        .out_bits({gap,any_valid})
     );
    for (genvar n = 0; n < MEMORY_REGS; n++) begin : ValidDataBuffer 
        BufferN #(.WIDTH(1+DATA_WIDTH),.DEPTH(6)) ValidDataBuffer (
            .clk(clk),
            .rst(rst),
            .in_bits({inValid[n],inData[n]}),
            .out_bits({outValid[n],outData[n]})
         );
     end
endmodule

module PopcountTree
    #(
        parameter int MEMORY_REGS = 64,                     // number of parallel samples
        // -------------------------------------------------------------------------
        // Tree geometry: round MEMORY_REGS up to next power-of-two for clean pairing
        // -------------------------------------------------------------------------
        localparam int P2      = 1 << $clog2(MEMORY_REGS),  // next power of 2
        localparam int STAGES  = $clog2(P2),                // number of adder stages
        localparam int ACC_WIDTH = $clog2(P2) + 1           // enough bits for 0..P2
    )(
        input  logic                    clk,
        input  logic                    rst,
        input  logic                    inValid [0:MEMORY_REGS-1],  // from gap detector
        output logic [ACC_WIDTH-1:0]    out_count       // 0..MEMORY_REGS (≤ P2)
    );

    // -------------------------------------------------------------------------
    // Stage storage: stage_valid[s], stage_data[s][node]
    // -------------------------------------------------------------------------
    logic                 stage_valid [0:STAGES];
    logic [ACC_WIDTH-1:0] stage_data  [0:STAGES][0:P2-1];

    // -------------------------------------------------------------------------
    // Stage 0: load input bits into data, mark valid
    // -------------------------------------------------------------------------
    integer i;
    always_comb begin
        stage_valid[0] = 1'b1;  // whole vector is "present"

        // initialize all P2 entries to 0
        for (i = 0; i < P2; i++) begin
            stage_data[0][i] = '0;
        end

        // copy MEMORY_REGS bits into lower entries as 0/1
        for (i = 0; i < MEMORY_REGS; i++) begin
            stage_data[0][i] = inValid[i];
        end
    end

    // -------------------------------------------------------------------------
    // Auto-built tree: each stage halves node count
    // -------------------------------------------------------------------------
    genvar s;
    generate
        for (s = 0; s < STAGES; s++) begin : TREE
            localparam int NODES = P2 >> (s+1);

            logic [ACC_WIDTH-1:0] stage_data_d [0:NODES-1];

            // combinational next-stage computation
            always_comb begin
                for (int n = 0; n < NODES; n++) begin
                    stage_data_d[n] = stage_data[s][2*n] + stage_data[s][2*n+1];
                end
            end

            // register data
            genvar n;
            for (n = 0; n < NODES; n++) begin : REG_STAGE
                RegBank #(.WIDTH(ACC_WIDTH)) reg_data (
                    .clk(clk),
                    .rst(rst),
                    .d(stage_data_d[n]),
                    .q(stage_data[s+1][n])
                );
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Final output: single node at last stage
    // -------------------------------------------------------------------------
    always_comb begin
        out_count <= stage_data[STAGES][0];  // popcount result
    end

endmodule

module ReciprocalLUT #(
    parameter int MEMORY_REGS = 64,
    parameter int OUT_WIDTH   = 38,     // Q1.31
    localparam int ADDR_WIDTH = $clog2(MEMORY_REGS+1)
)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic [ADDR_WIDTH-1:0]  N_valid,   // 0..MEMORY_REGS
    output logic [OUT_WIDTH-1:0]   recip_out,  // fixed-point reciprocal
    output logic outValid
);
    logic [OUT_WIDTH-1:0] Numerator = {1'b1,{(OUT_WIDTH-1){1'b0}}};
    logic [OUT_WIDTH-1:0] Denominator;
    logic [OUT_WIDTH-1:0] Result;
    integer i;
    logic non0;
    // ROM
    logic [OUT_WIDTH-1:0] RecipTable [0:MEMORY_REGS];
    logic [OUT_WIDTH-1:0] Reciprocal;

    // Generate-time constant initialization
    always_comb begin
        non0 = |N_valid;
        for (i = 0; i <= MEMORY_REGS; i++) begin : GEN_RECIP
            Denominator = (i == 0) ? 0 : i;
            RecipTable[i] = Numerator / Denominator;   // Q1.37 format
        end
        Reciprocal = RecipTable[N_valid];
    end

    // Pipeline register for timing alignment
    BufferN #(.WIDTH(1+OUT_WIDTH),.DEPTH(7)) Buffer (
        .clk(clk),
        .rst(rst),
        .in_bits({non0,Reciprocal}),
        .out_bits({outValid,recip_out})
     );

endmodule

 
// Differencer          - built
// difference of taus   - not required for allan - required for Hadamard
// squarer              - one squarer per tau
// accumulator          - done
// divider              - pending
// rooter               - pending