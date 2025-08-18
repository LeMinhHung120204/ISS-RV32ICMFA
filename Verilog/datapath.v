`timescale 1ns/1ps

module datapath #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_ADDR = 32
)(
    input clk, rst_n
);
    wire [WIDTH_DATA - 1:0] SrcA, WriteData;
    wire [WIDTH_DATA - 1:0] SrcB, Instr, ImmExt, ALUResult, ReadData;
    wire [WIDTH_ADDR - 1:0] PC, PCPlus4, PCTarget, PCNext;

    // ----------------------- Tin hieu dieu khien -----------------------
    wire RegWrite, ALUSrc, MemWrite, PCSrc, Zero;
    wire [1:0] ImmSrc, ResultSrc;
    wire [3:0] ALUControl;

    reg [WIDTH_DATA - 1:0] Result;

    assign SrcB     = (ALUSrc == 1'b1)  ? ImmExt    : WriteData; 
    assign PCNext   = (PCSrc == 1'b1)   ? PCTarget  : PCPlus4;
    assign PCPlus4  = PC + 32'd4;
    assign PCTarget = ImmExt + PC;

    always @(*) begin
        case(ALUResult)
            2'b00: begin
                Result = ALUResult; 
            end 
            2'b01: begin
                Result = ReadData;
            end 
            2'b10: begin
                Result = PCPlus4;
            end
            default Result = ALUResult; 
        endcase
    end 

    ControlUnit ControlUnit_ins(
        .op(Instr[6:0]),
        .funct3(Instr[14:12]),
        .funct7_5(Instr[30]),
        .Zero(Zero),
        .PCSrc(PCSrc),
        .ResultSrc(ResultSrc),
        .MemWrite(MemWrite),
        .ALUControl(ALUControl),
        .ALUSrc(ALUSrc),
        .ImmSrc(ImmSrc),
        .RegWrite(RegWrite)
    );

    PC PC_inst(
        .clk(clk),
        .rst_n(rst_n),
        .PCNext(PCNext),
        .PC(PC)
    );

    Ins_Mem instruction_memory(
        .clk(clk),
        .addr(PC),
        .instruction(Instr)
    );

    RegFile register_file(
        .clk(clk),
        .rst_n(rst_n),
        .we(RegWrite),
        .rs1(Instr[19:15]),
        .rs2(Instr[24:20]),
        .rd(Instr[11:7]),
        .wd(Result),
        .rd1(SrcA),
        .rd2(WriteData)
    );

    Extend extend_inst(
        .ImmSrc(ImmSrc),
        .Instr(Instr[31:0]),
        .ImmExt(ImmExt)
    );

    ALU alu_inst(
        .ALUControl(ALUControl),
        .in1(SrcA),
        .in2(SrcB),
        .result(ALUResult),
        .zero(Zero)
    );

    DataMem data_memory(
        .clk(clk),
        .rst_n(rst_n),
        .MemWrite(MemWrite),
        .addr(ALUResult),
        .data_in(WriteData),
        .rd(ReadData)
    );
endmodule 