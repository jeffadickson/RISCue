module rvfi_wrapper(input clock,reset,`RVFI_OUTPUTS);
 import ft_pkg::*;
 (* anyseq *) reg ready;
 (* anyseq *) reg [31:0] memory_data;
 rv32im_ft_core #(.BUS_TIMEOUT(32)) core(
  .clk(clock),.rst_n(!reset),.ready(ready),.bus_error(1'b0),.external_fault(1'b0),
  .rdata_code(ecc_encode(memory_data)),.fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0),
  `RVFI_CONN
 );
endmodule
