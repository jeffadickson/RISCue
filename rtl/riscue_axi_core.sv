// Generic processor wrapper: AXI4-Lite master to an external interconnect.
// Separate from the KV260 ARM-control AXI slave and its local ECC SRAM.
module riscue_axi_core #(
 parameter logic [31:0] RESET_PC=0,parameter integer BUS_TIMEOUT=1024,
 parameter bit RF_TMR=0,FI_ENABLE=0,EARLY_JUMP=1,MEMORY_FAULT_INPUT=0,MONITOR_CONTROL=0
)(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 CLK CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET aresetn" *) input logic aclk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 RESET RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input logic aresetn,
 input logic external_irq,external_memory_fault,
 input logic halt_request,input logic [31:0] boot_pc,output wire quiescent,bridge_idle,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWADDR", X_INTERFACE_PARAMETER="PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 32, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1" *) output logic [31:0] m_axi_awaddr,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *) output logic [2:0] m_axi_awprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *) output logic m_axi_awvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *) input logic m_axi_awready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WDATA" *) output logic [31:0] m_axi_wdata,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *) output logic [3:0] m_axi_wstrb,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WVALID" *) output logic m_axi_wvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI WREADY" *) input logic m_axi_wready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BRESP" *) input logic [1:0] m_axi_bresp,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BVALID" *) input logic m_axi_bvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI BREADY" *) output logic m_axi_bready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *) output logic [31:0] m_axi_araddr,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *) output logic [2:0] m_axi_arprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *) output logic m_axi_arvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *) input logic m_axi_arready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RDATA" *) input logic [31:0] m_axi_rdata,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RRESP" *) input logic [1:0] m_axi_rresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RVALID" *) input logic m_axi_rvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RREADY" *) output logic m_axi_rready,
 output logic halted,fatal,trap,output logic [31:0] pc,trap_cause,trap_value,
 output logic retire_valid,output logic [31:0] retire_pc,retire_insn,retire_result,
 output logic [4:0] retire_rd,
 output logic corrected_event,disagreement_event,bridge_fatal,
 output logic [7:0] core_event_flags,output logic [31:0] core_event_address,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output logic fi_ack
);
 logic req,ready,bus_error,core_fatal,core_ce,core_dis,bridge_ce,bridge_dis;
 logic [38:0] addr_code,wdata_code,ctrl_code,rdata_code;
 riscue_pipeline_core #(.RESET_PC(RESET_PC),.BUS_TIMEOUT(BUS_TIMEOUT),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.EARLY_JUMP(EARLY_JUMP),.MONITOR_CONTROL(MONITOR_CONTROL)) core(
  .clk(aclk),.rst_n(aresetn),.halt_request(halt_request),.boot_pc(boot_pc),.quiescent(quiescent),.external_irq(external_irq),.req(req),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
  .ready(ready),.bus_error(bus_error),.external_fault(bridge_fatal||(MEMORY_FAULT_INPUT&&external_memory_fault)),.rdata_code(rdata_code),
  .halted(halted),.fatal(core_fatal),.trap(trap),.trap_cause(trap_cause),.trap_value(trap_value),.pc(pc),
  .corrected_event(core_ce),.disagreement_event(core_dis),.retire_valid(retire_valid),.retire_pc(retire_pc),.retire_insn(retire_insn),.retire_result(retire_result),.retire_rd(retire_rd),
  .fi_valid(fi_valid),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(fi_ack),
  .event_flags(core_event_flags),.event_address(core_event_address));
 riscue_axi_master_bridge bridge(.idle(bridge_idle),.clk(aclk),.rst_n(aresetn),.core_req(req),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
  .core_ready(ready),.core_error(bus_error),.rdata_code(rdata_code),.corrected_event(bridge_ce),.disagreement_event(bridge_dis),.fatal(bridge_fatal),
  .m_axi_awaddr(m_axi_awaddr),.m_axi_awprot(m_axi_awprot),.m_axi_awvalid(m_axi_awvalid),.m_axi_awready(m_axi_awready),
  .m_axi_wdata(m_axi_wdata),.m_axi_wstrb(m_axi_wstrb),.m_axi_wvalid(m_axi_wvalid),.m_axi_wready(m_axi_wready),
  .m_axi_bresp(m_axi_bresp),.m_axi_bvalid(m_axi_bvalid),.m_axi_bready(m_axi_bready),
  .m_axi_araddr(m_axi_araddr),.m_axi_arprot(m_axi_arprot),.m_axi_arvalid(m_axi_arvalid),.m_axi_arready(m_axi_arready),
  .m_axi_rdata(m_axi_rdata),.m_axi_rresp(m_axi_rresp),.m_axi_rvalid(m_axi_rvalid),.m_axi_rready(m_axi_rready));
 assign fatal=core_fatal|bridge_fatal;
 assign corrected_event=core_ce|bridge_ce;
 assign disagreement_event=core_dis|bridge_dis;
endmodule
