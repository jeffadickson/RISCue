`timescale 1ns/1ps
module tb_axi_ecc_system #(parameter bit RF_TMR=0,parameter integer CASE=0,parameter bit INJECT_DED=0,parameter IMAGE="build/axi-c/smoke.hex",parameter GOLDEN="build/axi-c/smoke.expected");
 import ft_pkg::*;
 logic aclk=0,aresetn=0,external_irq=0;
 wire [31:0] m_axi_awaddr,m_axi_wdata,m_axi_araddr;wire [2:0] m_axi_awprot,m_axi_arprot;
 wire [3:0] m_axi_wstrb;wire m_axi_awvalid,m_axi_wvalid,m_axi_bready,m_axi_arvalid,m_axi_rready;
 wire m_axi_awready,m_axi_wready,m_axi_arready;
 wire [1:0] m_axi_bresp,m_axi_rresp;wire m_axi_bvalid,m_axi_rvalid;wire [31:0] m_axi_rdata;
 wire halted,fatal,trap,retire_valid,corrected_event,disagreement_event,bridge_fatal,fi_ack;
 wire [31:0] pc,trap_cause,trap_value,retire_pc,retire_insn,retire_result,core_event_address;
 wire [4:0] retire_rd;wire [7:0] core_event_flags;
 logic fi_valid=0;logic [3:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 wire external_memory_fault=memory_fatal;
 riscue_axi_core #(.RF_TMR(RF_TMR),.MEMORY_FAULT_INPUT(1)) dut(.*);
 always #5 aclk=~aclk;
 localparam integer WORDS=CASE==0?1024:2048;
 localparam integer MAILBOX=CASE==0?1008:1984;
 wire memory_fatal,mem_ce,mem_dis,event_valid,ram_fi_ack;
 wire [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,last_error_address;wire [5:0] last_error_syndrome;
 riscue_axi_ecc_ram #(.WORDS(WORDS),.INIT_FILE(IMAGE)) memory(.aclk(aclk),.aresetn(aresetn),.memory_reset(1'b0),.scrub_enable(1'b1),
  .s_axi_awaddr(m_axi_awaddr),
  .s_axi_awprot(m_axi_awprot),
  .s_axi_awvalid(m_axi_awvalid),
  .s_axi_awready(m_axi_awready),
  .s_axi_wdata(m_axi_wdata),
  .s_axi_wstrb(m_axi_wstrb),
  .s_axi_wvalid(m_axi_wvalid),
  .s_axi_wready(m_axi_wready),
  .s_axi_bresp(m_axi_bresp),
  .s_axi_bvalid(m_axi_bvalid),
  .s_axi_bready(m_axi_bready),
  .s_axi_araddr(m_axi_araddr),
  .s_axi_arprot(m_axi_arprot),
  .s_axi_arvalid(m_axi_arvalid),
  .s_axi_arready(m_axi_arready),
  .s_axi_rdata(m_axi_rdata),
  .s_axi_rresp(m_axi_rresp),
  .s_axi_rvalid(m_axi_rvalid),
  .s_axi_rready(m_axi_rready),
  .fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0),.fi_ack(ram_fi_ack),
  .fatal(memory_fatal),.corrected_event(mem_ce),.disagreement_event(mem_dis),.event_valid(event_valid),
  .corrected_count(corrected_count),.uncorrectable_count(uncorrectable_count),.disagreement_count(disagreement_count),.fatal_count(fatal_count),.last_error_address(last_error_address),.last_error_syndrome(last_error_syndrome));
 integer cycles=0,retired=0,finish_pc,j,irqs=0;logic [31:0] golden[0:31];ecc_result_t decoded;
 initial begin
  if(!$value$plusargs("finish_pc=%d",finish_pc))$fatal(1,"missing finish_pc");
  $readmemh(GOLDEN,golden);repeat(3)@(negedge aclk);if(INJECT_DED)memory.ram.mem[0]=memory.ram.mem[0]^39'd3;aresetn=1;
 end
 always @(negedge aclk)if(aresetn)begin
  cycles=cycles+1;
  if(INJECT_DED)begin
   if(fatal)begin if(retired!=0||!memory_fatal)$fatal(1,"instruction DED escaped");$display("PASS CPU-AXI-ECC instruction DED fail stop before retirement RF_TMR=%0d",RF_TMR);$finish;end
  end else if(fatal||memory_fatal)$fatal(1,"hardware fatal");
  if(trap)begin if(CASE!=1||trap_cause!=32'h80000007)$fatal(1,"unexpected trap");irqs=irqs+1;end
  if(retire_valid)begin
   retired=retired+1;
   if(retire_pc==finish_pc)begin
    for(j=0;j<32;j=j+1)if(golden[j]!==32'hxxxxxxxx)begin decoded=ecc_decode(memory.ram.mem[MAILBOX+j]);if(decoded.uncorrectable||decoded.data!==golden[j])$fatal(1,"mailbox[%0d] got=%h expected=%h",j,decoded.data,golden[j]);end
    if(CASE==1&&irqs!=1)$fatal(1,"missing timer interrupt");
    $display("PASS CPU-AXI-ECC C CASE=%0d RF_TMR=%0d cycles=%0d retirements=%0d IRQ=%0d",CASE,RF_TMR,cycles,retired,irqs);$finish;
   end
  end
  if(cycles>100000)$fatal(1,"execution timeout");
 end
endmodule
