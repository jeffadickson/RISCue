// Reproduce the pinned model's signed ternary context issue with a second tool.
module tb_formal_model_context;
 logic [31:0] insn,a,b;
 wire [31:0] model_div,model_rem;
 ft_pkg::exec_t actual;
 rv32_execute dut(insn,32'h0,a,b,actual);
 rvfi_insn_div div_model(.rvfi_valid(1'b1),.rvfi_insn(insn),.rvfi_pc_rdata(32'b0),.rvfi_rs1_rdata(a),.rvfi_rs2_rdata(b),.rvfi_mem_rdata(32'b0),.spec_rd_wdata(model_div));
 rvfi_insn_rem rem_model(.rvfi_valid(1'b1),.rvfi_insn(insn),.rvfi_pc_rdata(32'b0),.rvfi_rs1_rdata(a),.rvfi_rs2_rdata(b),.rvfi_mem_rdata(32'b0),.spec_rd_wdata(model_rem));
 initial begin
  insn=32'h0220c1b3;a=32'h80000000;b=32'hffff0000;#1;
  if(actual.result!=32'h8000)$fatal(1,"core signed quotient wrong");
`ifdef PATCHED_MODEL
  if(model_div!=32'h8000)$fatal(1,"patched signed quotient wrong");
`else
  if(model_div!=0)$fatal(1,"pinned model context reproducer changed");
`endif
  insn=32'h0220e1b3;a=32'hffffffff;b=32'h80000000;#1;
  if(actual.result!=32'hffffffff)$fatal(1,"core signed remainder wrong");
`ifdef PATCHED_MODEL
  if(model_rem!=32'hffffffff)$fatal(1,"patched signed remainder wrong");
`else
  if(model_rem!=32'h7fffffff)$fatal(1,"pinned model context reproducer changed");
`endif
  $display("PASS signed model context regression");$finish;
 end
endmodule
