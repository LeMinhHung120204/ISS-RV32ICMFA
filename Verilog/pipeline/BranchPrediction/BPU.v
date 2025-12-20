`timescale 1ns / 1ps
// Branch Prediction Unit
// from Lee Min Hunz with love
module BPU #(
    parameter W_ADDR = 32
)(
    input               clk, rst_n,
    input [W_ADDR-1:0]  F_PC,                 
    input [W_ADDR-1:0]  E_PC,           
    input [W_ADDR-1:0]  E_PCTarget,  
    input               E_branch,        
    input               E_jump,          
    input               taken,   
    input [2:0]         E_GHSR,          

    output              predict_taken,  
    output [W_ADDR-1:0] target_pc,      
    output [2:0]        F_GHSR 
);
    wire                btb_hit;
    wire                pht_predict_taken;
    wire [W_ADDR-1:0]   btb_pred_addr;
    
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
        .E_branch       (E_branch),    
        .E_jump         (E_jump),

        .pc_prediction  (btb_pred_addr),
        .hit            (btb_hit)       
    );

    PHT Pattern_History_Table (
        .clk            (clk),
        .rst_n          (rst_n),
        .E_branch       (E_branch),    
        .E_jump         (E_jump),      
        .Taken          (taken),      
        .E_PC           (E_PC[4:2]),
        .E_GHSR         (E_GHSR),                  
        .F_PC           (F_PC[4:2]),     
          
        .predict        (pht_predict_taken),
        .GHSR_out       (F_GHSR)
    );

endmodule