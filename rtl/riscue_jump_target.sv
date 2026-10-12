// Direct JAL target only. RV32C C.J/C.JAL arrive expanded as JAL.
// Separate instances are preserved and compared before ID redirection.
module riscue_jump_target(input logic [31:0] insn,pc,output logic [31:0] target);
 wire [31:0] offset={{11{insn[31]}},insn[31],insn[19:12],insn[20],insn[30:21],1'b0};
 assign target=pc+offset;
endmodule
