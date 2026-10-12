module rvfi_wrapper(input clock,reset,`RVFI_OUTPUTS);
 import ft_pkg::*;
 (* anyseq *) reg ready;
 (* anyseq *) reg [31:0] memory_data;
 assign rvfi_mode=2'b11;assign rvfi_ixl=2'b01;assign rvfi_halt=0;
 riscue_pipeline_core #(.BUS_TIMEOUT(256)) core(
  .clk(clock),.rst_n(!reset),.external_irq(1'b0),.ready(ready),.bus_error(1'b0),.external_fault(1'b0),
  .rdata_code(ecc_encode(memory_data)),.fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0),
  .retire_valid(rvfi_valid),.retire_pc(rvfi_pc_rdata),.retire_insn(rvfi_insn),.retire_rd(rvfi_rd_addr),.retire_result(rvfi_rd_wdata),
  .rvfi_order(rvfi_order),.rvfi_trap(rvfi_trap),.rvfi_intr(rvfi_intr),.rvfi_pc_wdata(rvfi_pc_wdata),
  .rvfi_rs1_addr(rvfi_rs1_addr),.rvfi_rs2_addr(rvfi_rs2_addr),.rvfi_rs1_rdata(rvfi_rs1_rdata),.rvfi_rs2_rdata(rvfi_rs2_rdata),
  .rvfi_mem_addr(rvfi_mem_addr),.rvfi_mem_rmask(rvfi_mem_rmask),.rvfi_mem_wmask(rvfi_mem_wmask),
  .rvfi_mem_rdata(rvfi_mem_rdata),.rvfi_mem_wdata(rvfi_mem_wdata)
 );
endmodule
