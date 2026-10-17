module riscue_packet_soc #(
 parameter integer PIPELINE_PROTECTION=`RISCUE_PIPELINE_PROTECTION,
 parameter bit ALLOW_EXPERIMENTAL_PARITY=`RISCUE_ALLOW_EXPERIMENTAL_PARITY,
 parameter integer CLOCK_HZ=10000000,BAUD=115200,WORDS=2048,parameter INIT_FILE="",parameter integer BUS_TIMEOUT=1024,
 parameter bit RF_TMR=0,parameter bit FI_ENABLE=0,EARLY_JUMP=1
)(
 input logic clk,rst_n,external_irq,rx,output wire tx,
 input logic packet_fi_valid,input logic [1:0] packet_fi_target,input logic [31:0] packet_fi_index,input logic [511:0] packet_fi_mask,output wire packet_fi_ack,packet_fatal,packet_irq,
 output logic halted,fatal,trap,
 output logic [31:0] trap_cause,trap_value,pc,
 output logic corrected_event,disagreement_event,
 output logic retire_valid,
 output logic [31:0] retire_pc,retire_insn,retire_result,
 output logic [4:0] retire_rd,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,
 input logic [511:0] fi_mask,output logic fi_ack,
 output logic event_valid,output logic [15:0] sticky_flags,
 output logic [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,
 output logic [31:0] first_pc,first_address,last_pc,last_address,
 output logic [15:0] first_flags,last_flags
);
 wire [31:0] injection_width=riscue_pipeline_pkg::fi_width(RF_TMR,WORDS,fi_target,fi_index);
 wire fi_dispatch=rst_n&&fi_valid&&injection_width!=0&&fi_mask!=0&&(fi_mask>>injection_width)==0;
 logic req,ready,error,mem_fatal,mem_ce,mem_dis,core_ce,core_dis,report_dis;
 logic core_ack,mem_ack,report_ack;
 wire uart_ready,uart_error,ram_ready,ram_error,uart_ce,uart_dis;
 wire [38:0] uart_data,ram_data;
 ft_pkg::ecc_result_t address_decoded;
 always_comb address_decoded=ft_pkg::ecc_decode(addr_code);
 wire select_uart=!address_decoded.uncorrectable&&address_decoded.data[31:8]==24'h100000;
 assign ready=select_uart?uart_ready:ram_ready;
 assign error=select_uart?uart_error:ram_error;
 assign rdata_code=select_uart?uart_data:ram_data;
 riscue_packet_uart #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD),.FI_ENABLE(FI_ENABLE)) uart(
 .clk(clk),.rst_n(rst_n),.rx(rx),.tx(tx),.req(req&&select_uart),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
 .ready(uart_ready),.error(uart_error),.rdata_code(uart_data),.irq(packet_irq),.fatal(packet_fatal),.corrected_event(uart_ce),.disagreement_event(uart_dis),
 .fi_valid(FI_ENABLE&&packet_fi_valid),.fi_target(packet_fi_target),.fi_index(packet_fi_index),.fi_mask(packet_fi_mask),.fi_ack(packet_fi_ack));
 logic [7:0] core_flags,mem_flags;logic [31:0] core_address,mem_address;
 logic [38:0] addr_code,wdata_code,ctrl_code,rdata_code;
 riscue_pipeline_core #(.PIPELINE_PROTECTION(PIPELINE_PROTECTION),.ALLOW_EXPERIMENTAL_PARITY(ALLOW_EXPERIMENTAL_PARITY),.BUS_TIMEOUT(BUS_TIMEOUT),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.EARLY_JUMP(EARLY_JUMP)) core(
  .clk(clk),.rst_n(rst_n),.halt_request(1'b0),.boot_pc(32'd0),.quiescent(),.external_irq(external_irq|packet_irq),.req(req),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
  .ready(ready),.bus_error(error),.external_fault(mem_fatal|packet_fatal),.rdata_code(rdata_code),
  .halted(halted),.fatal(fatal),.trap(trap),.trap_cause(trap_cause),.trap_value(trap_value),.pc(pc),
  .corrected_event(core_ce),.disagreement_event(core_dis),.retire_valid(retire_valid),
  .retire_pc(retire_pc),.retire_insn(retire_insn),.retire_result(retire_result),.retire_rd(retire_rd),
  .fi_valid(fi_dispatch),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(core_ack),
  .event_flags(core_flags),.event_address(core_address));
 ft_ecc_ram #(.WORDS(WORDS),.INIT_FILE(INIT_FILE),.FI_ENABLE(FI_ENABLE),.FAIL_STOP_DED(1)) ram(
  .clk(clk),.rst_n(rst_n),.req(req&&!select_uart),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
  .ready(ram_ready),.error(ram_error),.rdata_code(ram_data),.corrected_event(mem_ce),.fatal(mem_fatal),.disagreement_event(mem_dis),
  .fi_valid(fi_dispatch),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(mem_ack),
  .event_flags(mem_flags),.event_address(mem_address));
 ft_event_monitor #(.FI_ENABLE(FI_ENABLE)) reporter(
  .clk(clk),.rst_n(rst_n),.flags({mem_flags|{4'd0,packet_fatal,uart_dis,1'b0,uart_ce},core_flags}),.observation_pc(pc),
  .observation_address((uart_ce||uart_dis||packet_fatal)?address_decoded.data:((mem_flags!=0)?mem_address:core_address)),
  .fi_valid(fi_dispatch),.fi_target(fi_target),.fi_mask(fi_mask),.fi_ack(report_ack),
  .event_valid(event_valid),.sticky_flags(sticky_flags),.corrected_count(corrected_count),
  .uncorrectable_count(uncorrectable_count),.disagreement_count(disagreement_count),.fatal_count(fatal_count),
  .first_pc(first_pc),.first_address(first_address),.first_flags(first_flags),
  .last_pc(last_pc),.last_address(last_address),.last_flags(last_flags),.report_disagreement(report_dis));
 assign corrected_event=core_ce|mem_ce|uart_ce;
 assign disagreement_event=core_dis|mem_dis|report_dis|uart_dis;
 assign fi_ack=core_ack|mem_ack|report_ack;
endmodule
