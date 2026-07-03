`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2026 03:10:40 PM
// Design Name: 
// Module Name: TB_ReciprocalLUT
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module TB_ReciprocalLUT();
    //parameters
    localparam DATA_WIDTH = 16;
    localparam MEMORY_REGS = 64;
    localparam OUT_WIDTH = (2*DATA_WIDTH) + $clog2(MEMORY_REGS);
    localparam ADDR_WIDTH = $clog2(MEMORY_REGS+1);

    //DUT inputs
    logic clk; //Clock
    logic rst; // reset Active High
    logic [ADDR_WIDTH-1:0]  N_valid;   // 0..MEMORY_REGS
    logic [OUT_WIDTH-1:0]   recip_out;  // fixed-point reciprocal
    logic outValid;
    
    ReciprocalLUT #(
        .MEMORY_REGS(MEMORY_REGS),
        .OUT_WIDTH((2*DATA_WIDTH) + $clog2(MEMORY_REGS))
    )u_RecipLUT(
        .clk(clk),
        .rst(rst),
        .N_valid(N_valid),
        .recip_out(recip_out),
        .outValid(outValid)
    );
    
    //clock gen: 100 MHz
    initial clk = 1;
    always #5 clk = ~clk;
    
    //Stimulus
    initial begin
        // Initialize
        rst = 1;
        N_valid = 0;
        repeat(1) @(posedge clk);
        rst = 0;
        //repeat(1) @(posedge clk);
        // feed 100 samples
        for(int i = 0; i <= MEMORY_REGS; i++) begin
            N_valid = i;
            @(posedge clk);
        end
        repeat(24) @(posedge clk);
        $display("Simulation Complete");
        $finish;
    end 
endmodule
