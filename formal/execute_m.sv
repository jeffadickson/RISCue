// Combinational contract against the pinned upstream model, arbitrary operands.
module formal_execute_m;
 import ft_pkg::*;
 (* anyconst *) reg [31:0] a,b,pc;
 (* anyconst *) reg [4:0] rs1,rs2,rd;
 wire [31:0] insn={7'b0000001,rs2,rs1,`M_FUNCT3,rd,7'b0110011};
 wire [31:0] av=rs1==0?32'b0:a,bv=rs2==0?32'b0:b;
 wire valid,trap;
 wire [4:0] spec_rd;
 wire [31:0] result,next_pc;
 exec_t actual;
 rv32_execute dut(insn,pc,av,bv,actual);
 `M_MODEL spec(.rvfi_valid(1'b1),.rvfi_insn(insn),.rvfi_pc_rdata(pc),
  .rvfi_rs1_rdata(av),.rvfi_rs2_rdata(bv),.rvfi_mem_rdata(32'b0),
  .spec_valid(valid),.spec_trap(trap),.spec_rd_addr(spec_rd),.spec_rd_wdata(result),.spec_pc_wdata(next_pc));
 always @*begin
  assume(pc[1:0]==0);
  assert(valid&&!trap&&!actual.trap&&!actual.mem&&actual.rd_we);
  assert(actual.rd==spec_rd);
  assert((actual.rd==0?32'b0:actual.result)==result);
  assert(actual.next_pc==next_pc);
  cover(valid&&rd!=0&&a!=0&&b!=0);
 end
endmodule
