`timescale 1ns / 1ps
// from Lee Min Hunz with luv
// ============================================================================
// BPU - Branch Prediction Unit
// ============================================================================
// Combines BTB (Branch Target Buffer) and PHT (Pattern History Table)
// to predict branch direction and target address.
// Prediction: taken = BTB hit AND PHT predicts taken
// ============================================================================
module BPU #(
    parameter W_ADDR = 32
)(
    input               clk, rst_n
,   input [W_ADDR-1:1]  F_PC                 
,   input [W_ADDR-1:1]  E_PC           
,   input [W_ADDR-1:0]  E_PCTarget  
,   input               E_Branch        
,   input               E_Jump          
,   input               taken   
,   input [2:0]         E_GHSR          

,   output              predict_taken  
,   output [W_ADDR-1:0] target_pc      
,   output [2:0]        F_GHSR 
);
    // ================================================================
    // INTERNAL SIGNALS
    // ================================================================
    wire                btb_hit;            // BTB found matching entry
    wire                pht_predict_taken;  // PHT predicts branch taken
    wire [W_ADDR-1:0]   btb_pred_addr;      // Predicted target from BTB
    
    // Final prediction: BTB must hit AND PHT must predict taken
    assign predict_taken    = btb_hit & pht_predict_taken;
    assign target_pc        = btb_pred_addr; 

    BTB #(
        .W_ADDR(W_ADDR)
    ) Branch_Target_Buffer (
        .clk            (clk),
        .rst_n          (rst_n),
        .F_PC           (F_PC),
        .E_PC           (E_PC),            
        .branch_target  (E_PCTarget),
        .E_Branch       (E_Branch),    
        .E_Jump         (E_Jump),

        .pc_prediction  (btb_pred_addr),
        .hit            (btb_hit)       
    );

    PHT Pattern_History_Table (
        .clk            (clk),
        .rst_n          (rst_n),
        .E_Branch       (E_Branch),    
        .E_Jump         (E_Jump),      
        .Taken          (taken),      
        .E_PC           (E_PC[4:2]),
        .E_GHSR         (E_GHSR),                  
        .F_PC           (F_PC[4:2]),     
          
        .predict        (pht_predict_taken),
        .GHSR_out       (F_GHSR)
    );

endmodule