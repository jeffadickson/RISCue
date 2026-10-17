// Dedicated lab debug target. The debug and application reset domains are separate.
// SBA owns ECC SRAM only while the core is halted and its bus is quiescent.
module riscue_debug_soc #(
 parameter integer PIPELINE_PROTECTION=`RISCUE_PIPELINE_PROTECTION,
 parameter bit ALLOW_EXPERIMENTAL_PARITY=`RISCUE_ALLOW_EXPERIMENTAL_PARITY,parameter integer WORDS=2048,parameter INIT_FILE="",parameter bit RF_TMR=0,EARLY_JUMP=1)(
 input logic clk,rst_n,tck,tms,tdi,input logic external_irq,output logic tdo,
 output logic debug_halted,fatal,trap,retire_valid,output logic [31:0] pc,retire_pc,retire_insn
);
 import ft_pkg::*;
 wire dmi_valid,dmi_write;wire [6:0] dmi_addr;wire [31:0] dmi_wdata,dmi_rdata;
 riscue_jtag_dtm dtm(.*);
 wire haltreq,resumereq,ndmreset,resumeack,reg_valid,reg_write,reg_ready,reg_error,dm_fault,dm_dis;
 wire [15:0] regno;wire [31:0] reg_wdata,reg_rdata;
 wire sb_req,sb_write,sb_ready,sb_error;wire [31:0] sb_addr,sb_wdata,sb_rdata;wire [3:0] sb_mask;
 riscue_debug_module dm(.clk(clk),.rst_n(rst_n),.dmi_valid(dmi_valid),.dmi_write(dmi_write),.dmi_addr(dmi_addr),.dmi_wdata(dmi_wdata),.dmi_rdata(dmi_rdata),
  .hart_halted(debug_halted),.hart_resumeack(resumeack),.hart_fatal(fatal),.haltreq(haltreq),.resumereq(resumereq),.ndmreset(ndmreset),
  .reg_valid(reg_valid),.reg_write(reg_write),.regno(regno),.reg_wdata(reg_wdata),.reg_ready(reg_ready),.reg_error(reg_error),.reg_rdata(reg_rdata),
  .bus_req(sb_req),.bus_write(sb_write),.bus_addr(sb_addr),.bus_wdata(sb_wdata),.bus_mask(sb_mask),.bus_ready(sb_ready),.bus_error(sb_error),.bus_rdata(sb_rdata),.fault(dm_fault),.disagreement(dm_dis));
 wire core_reset_n=rst_n&&!ndmreset;
 wire core_req,core_ready,core_error,quiescent,ram_req,ram_ready,ram_error,ram_fatal;
 wire [38:0] core_ac,core_wc,core_cc,ram_ac,ram_wc,ram_cc,ram_rc;
 wire sb_owner=debug_halted&&quiescent&&!core_req;
 wire sb_grant=sb_owner&&sb_req;
 assign ram_req=sb_grant||core_req;
 assign ram_ac=sb_grant?ecc_encode(sb_addr):core_ac;
 assign ram_wc=sb_grant?ecc_encode(sb_wdata):core_wc;
 assign ram_cc=sb_grant?ecc_encode(sb_write?32'h10|{28'b0,sb_mask}:0):core_cc;
 assign core_ready=ram_ready&&!sb_owner;assign core_error=ram_error;
 ecc_result_t decoded;
 always_comb decoded=ecc_decode(ram_rc);
 assign sb_ready=ram_ready&&sb_grant;assign sb_error=ram_error||decoded.uncorrectable;
 assign sb_rdata=decoded.data;
 riscue_pipeline_core #(.PIPELINE_PROTECTION(PIPELINE_PROTECTION),.ALLOW_EXPERIMENTAL_PARITY(ALLOW_EXPERIMENTAL_PARITY),.RF_TMR(RF_TMR),.EARLY_JUMP(EARLY_JUMP),.DEBUG_ENABLE(1)) core(
  .clk(clk),.rst_n(core_reset_n),.external_irq(external_irq),.halt_request(1'b0),.boot_pc(32'b0),.quiescent(quiescent),
  .debug_haltreq(haltreq),.debug_resumereq(resumereq),.debug_halted(debug_halted),.debug_resumeack(resumeack),
  .debug_reg_valid(reg_valid),.debug_reg_write(reg_write),.debug_regno(regno),.debug_wdata(reg_wdata),.debug_rdata(reg_rdata),.debug_reg_ready(reg_ready),.debug_reg_error(reg_error),
  .req(core_req),.addr_code(core_ac),.wdata_code(core_wc),.ctrl_code(core_cc),.ready(core_ready),.bus_error(core_error),.external_fault(ram_fatal||dm_fault),.rdata_code(ram_rc),
  .fatal(fatal),.trap(trap),.pc(pc),.retire_valid(retire_valid),.retire_pc(retire_pc),.retire_insn(retire_insn),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0));
 ft_ecc_ram #(.WORDS(WORDS),.INIT_FILE(INIT_FILE),.FAIL_STOP_DED(1),.EXTERNAL_SCRUB_CONTROL(1)) ram(
  .clk(clk),.rst_n(core_reset_n),.req(ram_req),.scrub_enable(!debug_halted),.addr_code(ram_ac),.wdata_code(ram_wc),.ctrl_code(ram_cc),
  .ready(ram_ready),.error(ram_error),.rdata_code(ram_rc),.fatal(ram_fatal),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0));
endmodule
