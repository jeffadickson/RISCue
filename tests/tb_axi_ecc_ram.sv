`timescale 1ns/1ps
module tb_axi_ecc_ram;
 import ft_pkg::*;
 logic aclk=0,aresetn=0,external_irq=0;
 logic [31:0] s_axi_awaddr=0,s_axi_wdata=0,s_axi_araddr=0;logic [2:0] s_axi_awprot=0,s_axi_arprot=0;
 logic [3:0] s_axi_wstrb=0;logic s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=0,s_axi_arvalid=0,s_axi_rready=0;
 wire s_axi_awready,s_axi_wready,s_axi_arready;
 wire [1:0] s_axi_bresp,s_axi_rresp;wire s_axi_bvalid,s_axi_rvalid;wire [31:0] s_axi_rdata;
 wire halted,fatal,trap,retire_valid,corrected_event,disagreement_event,bridge_fatal,fi_ack;
 wire [31:0] pc,trap_cause,trap_value,retire_pc,retire_insn,retire_result,core_event_address;
 wire [4:0] retire_rd;wire [7:0] core_event_flags;
 logic fi_valid=0;logic [3:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 logic memory_reset=0,scrub_enable=0;wire [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,last_error_address;wire [5:0] last_error_syndrome;wire event_valid;
 riscue_axi_ecc_ram #(.WORDS(16),.FI_ENABLE(1)) dut(.*);
 always #5 aclk=~aclk;
 task tick;begin @(negedge aclk);#1;end endtask
 task write(input [31:0] addr,data,input [3:0] mask,input integer order,input [1:0] response);
  integer k;begin
   s_axi_awaddr=addr;s_axi_wdata=data;s_axi_wstrb=mask;
   if(order==0)begin s_axi_awvalid=1;do @(posedge aclk);while(!s_axi_awready);tick();s_axi_awvalid=0;repeat(2)tick();s_axi_wvalid=1;do @(posedge aclk);while(!s_axi_wready);tick();s_axi_wvalid=0;end
   else begin s_axi_wvalid=1;do @(posedge aclk);while(!s_axi_wready);tick();s_axi_wvalid=0;repeat(2)tick();s_axi_awvalid=1;do @(posedge aclk);while(!s_axi_awready);tick();s_axi_awvalid=0;end
   k=0;while(!s_axi_bvalid&&k<20)begin tick();k=k+1;end
   if(!s_axi_bvalid||s_axi_bresp!=response)$fatal(1,"write response %h",s_axi_bresp);
   repeat(3)begin tick();if(!s_axi_bvalid||s_axi_bresp!=response)$fatal(1,"B backpressure");end
   s_axi_bready=1;tick();s_axi_bready=0;repeat(2)tick();
  end
 endtask
 logic upset_done=0;
 task read(input [31:0] addr,expected,input [1:0] response);
  integer k;begin
   s_axi_araddr=addr;s_axi_arvalid=1;do @(posedge aclk);while(!s_axi_arready);tick();s_axi_arvalid=0;
   k=0;while(!s_axi_rvalid&&k<20)begin tick();k=k+1;end
   if(!s_axi_rvalid||s_axi_rresp!=response||s_axi_rdata!==expected)$fatal(1,"read got %h/%h expected %h/%h",s_axi_rdata,s_axi_rresp,expected,response);
   if(!upset_done)begin
    dut.s0=dut.s0^(512'd1<<166);#1;if(!disagreement_event||fatal)$fatal(1,"AXI controller upset detect");upset_done=1;
   end
   repeat(3)begin tick();if(!s_axi_rvalid||s_axi_rdata!==expected||s_axi_rresp!=response)$fatal(1,"R backpressure");end
   s_axi_rready=1;tick();s_axi_rready=0;repeat(2)tick();
  end
 endtask
 task inject(input [31:0] index,input [511:0] mask);
  begin fi_target=8;fi_index=index;fi_mask=mask;fi_valid=1;#1;if(!fi_ack)$fatal(1,"FI rejected");tick();fi_valid=0;tick();end
 endtask
 logic [38:0] bad;integer j;
 initial begin
  repeat(3)tick();aresetn=1;
  fi_valid=1;fi_target=8;fi_index=16;fi_mask=1;#1;if(fi_ack)$fatal(1,"FI bounds");tick();
  fi_index=0;fi_mask=512'd1<<39;#1;if(fi_ack)$fatal(1,"FI mask width");tick();
  fi_target=9;fi_index=1;fi_mask=1;#1;if(fi_ack)$fatal(1,"FI control index");tick();
  fi_valid=0;tick();if(dut.ram.mem[0]!==ecc_encode(0))$fatal(1,"invalid FI mutation");
  write(8,32'h11223344,15,0,0);read(8,32'h11223344,0);
  write(8,32'h0000aa00,2,1,0);read(8,32'h1122aa44,0);
  write(8,0,0,0,0);read(8,32'h1122aa44,0);
  // Every physical code bit is correctable and rewritten on read.
  for(j=0;j<39;j=j+1)begin inject(2,512'd1<<j);read(8,32'h1122aa44,0);if(dut.ram.mem[2]!==ecc_encode(32'h1122aa44))$fatal(1,"repair missed bit %0d",j);end
  inject(3,1);scrub_enable=1;repeat(40)tick();scrub_enable=0;
  if(dut.ram.mem[3]!==ecc_encode(0)||corrected_count<40)$fatal(1,"scrub correction");
  read(64,0,3);write(3,1,15,1,3);
  inject(2,3);bad=dut.ram.mem[2];write(8,32'hffff0000,12,1,2);
  if(!fatal||dut.ram.mem[2]!==bad||uncorrectable_count==0||last_error_address!=8||last_error_syndrome!=3)$fatal(1,"DED partial write/telemetry");
  read(8,0,2);memory_reset=1;tick();memory_reset=0;tick();
  write(8,32'h55667788,15,0,0);read(8,32'h55667788,0);
  inject(2,3);read(8,0,2);if(!fatal)$fatal(1,"DED read not fatal");
  if(uncorrectable_count<2||fatal_count<2)$fatal(1,"missing DED telemetry");
  if(disagreement_count==0)$fatal(1,"AXI TMR repair missing");
  memory_reset=1;tick();memory_reset=0;tick();write(8,32'h55667788,15,0,0);
  inject(4,3);scrub_enable=1;repeat(40)tick();scrub_enable=0;
  if(!fatal||uncorrectable_count<3||last_error_address!=16||last_error_syndrome!=3)$fatal(1,"scrub DED telemetry");
  memory_reset=1;tick();memory_reset=0;tick();
  dut.ram.s0=dut.ram.s0^35'd1;dut.ram.s1=dut.ram.s1^35'd2;#1;
  if(!fatal)$fatal(1,"RAM control lost-majority containment");tick();if(!fatal)$fatal(1,"RAM control fatal not latched");
  aresetn=0;tick();aresetn=1;tick();
  s_axi_araddr=0;s_axi_arvalid=1;do @(posedge aclk);while(!s_axi_arready);tick();s_axi_arvalid=0;
  memory_reset=1;tick();if(!fatal)$fatal(1,"unsafe busy reset not rejected");memory_reset=0;
  $display("PASS AXI ECC RAM: AW/W order, B/R backpressure, masks, 39 single-bit repairs, scrub, DED read/partial-write suppression, recovery and syndrome telemetry");$finish;
 end
 initial begin #100000;$fatal(1,"test timeout");end
endmodule
