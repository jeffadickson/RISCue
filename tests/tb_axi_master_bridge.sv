`timescale 1ns/1ps
module tb_axi_master_bridge;
 wire idle;
 import ft_pkg::*;
 logic aclk=0,aresetn=0,external_irq=0;
 wire [31:0] m_axi_awaddr,m_axi_wdata,m_axi_araddr;wire [2:0] m_axi_awprot,m_axi_arprot;
 wire [3:0] m_axi_wstrb;wire m_axi_awvalid,m_axi_wvalid,m_axi_bready,m_axi_arvalid,m_axi_rready;
 logic m_axi_awready,m_axi_wready,m_axi_arready;
 logic [1:0] m_axi_bresp=0,m_axi_rresp=0;logic m_axi_bvalid=0,m_axi_rvalid=0;logic [31:0] m_axi_rdata=0;
 wire halted,fatal,trap,retire_valid,corrected_event,disagreement_event,bridge_fatal,fi_ack;
 wire [31:0] pc,trap_cause,trap_value,retire_pc,retire_insn,retire_result,core_event_address;
 wire [4:0] retire_rd;wire [7:0] core_event_flags;
 logic fi_valid=0;logic [3:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 logic core_req=0;wire core_ready,core_error;
 logic [38:0] addr_code,wdata_code,ctrl_code;wire [38:0] rdata_code;
 riscue_axi_master_bridge dut(.clk(aclk),.rst_n(aresetn),.fatal(bridge_fatal),.*);
 always #5 aclk=~aclk;
 task tick;begin @(negedge aclk);#1;end endtask
 initial begin
  addr_code=ecc_encode(32'h42);wdata_code=ecc_encode(32'hdeadbeef);ctrl_code=ecc_encode(0);
  m_axi_awready=0;m_axi_wready=0;m_axi_arready=0;
  repeat(3)tick();aresetn=1;core_req=1;tick();
  repeat(3)begin if(!m_axi_arvalid||m_axi_araddr!=32'h40)$fatal(1,"Read address unstable");tick();end
  core_req=0; // Dropped requester does not cancel an AXI transaction.
  m_axi_arready=1;tick();m_axi_arready=0;
  if(!m_axi_rready)$fatal(1,"No RREADY");
  m_axi_rvalid=1;m_axi_rdata=32'habcd1234;tick();m_axi_rvalid=0;
  if(!core_ready||core_error||rdata_code!==ecc_encode(32'habcd1234))$fatal(1,"Read response");
  tick();tick();if(core_ready||m_axi_arvalid)$fatal(1,"Duplicate read");
  addr_code=ecc_encode(32'h123);wdata_code=ecc_encode(32'h10203040);ctrl_code=ecc_encode(32'h1a);core_req=1;tick();
  m_axi_wready=1;tick();m_axi_wready=0;core_req=0;
  addr_code=ecc_encode(0);wdata_code=ecc_encode(0);ctrl_code=ecc_encode(0);
  repeat(3)begin if(!m_axi_awvalid||m_axi_wvalid||m_axi_awaddr!=32'h120||m_axi_wdata!=32'h10203040||m_axi_wstrb!=10)$fatal(1,"Write ownership");tick();end
  dut.s0=dut.s0^1;#1;if(!disagreement_event||bridge_fatal)$fatal(1,"TMR detect");tick();
  if(disagreement_event||bridge_fatal||!m_axi_awvalid)$fatal(1,"TMR repair");
  m_axi_awready=1;tick();m_axi_awready=0;
  if(!m_axi_bready)$fatal(1,"No BREADY");
  m_axi_bvalid=1;m_axi_bresp=3;tick();m_axi_bvalid=0;
  if(!core_ready||!core_error)$fatal(1,"DECERR handling");tick();tick();
  core_req=1;ctrl_code=ecc_encode(32'h80000000);tick();
  if(!core_ready||!core_error||m_axi_arvalid||m_axi_awvalid)$fatal(1,"Malformed control issued");
  tick();repeat(3)begin if(core_ready||m_axi_arvalid||m_axi_awvalid)$fatal(1,"Held request replay");tick();end
  core_req=0;tick();
  ctrl_code=ecc_encode(0);addr_code=ecc_encode(32'h80)^39'd1;core_req=1;tick();
  if(!corrected_event||bridge_fatal||m_axi_araddr!=32'h80)$fatal(1,"ECC correction");
  aresetn=0;tick();aresetn=1;core_req=1;addr_code=ecc_encode(32'h80)^39'd3;tick();
  if(!bridge_fatal||m_axi_arvalid||m_axi_awvalid)$fatal(1,"ECC DED fail stop");
  $display("PASS AXI bridge ownership/drain, W-before-AW, response error, TMR repair, held request, ECC correction/DED");$finish;
 end
endmodule
