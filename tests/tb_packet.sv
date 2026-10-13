`timescale 1ns/1ps
module tb_packet #(parameter bit RF_TMR=0);
 import ft_pkg::*;
 logic clk=0,rst_n=0,rx=1;wire tx;
 always #5 clk=~clk;
 wire halted,fatal,trap,corrected_event,disagreement_event,retire_valid,event_valid,packet_fatal,packet_irq,packet_fi_ack;
 wire [31:0] trap_cause,trap_value,pc,retire_pc,retire_insn,retire_result,corrected_count,uncorrectable_count,disagreement_count,fatal_count,first_pc,first_address,last_pc,last_address;
 logic inject_valid=0;logic [511:0] inject_mask=0;
 wire [4:0] retire_rd;wire [15:0] sticky_flags,first_flags,last_flags;wire fi_ack;
 riscue_packet_soc #(.CLOCK_HZ(1280000),.BAUD(10000),.INIT_FILE("build/packet/packet.hex"),.RF_TMR(RF_TMR),.FI_ENABLE(1)) dut(
 .clk(clk),.rst_n(rst_n),.rx(rx),.tx(tx),.external_irq(1'b0),
 .halted(halted),.fatal(fatal),.trap(trap),.trap_cause(trap_cause),.trap_value(trap_value),.pc(pc),
 .corrected_event(corrected_event),.disagreement_event(disagreement_event),.retire_valid(retire_valid),.retire_pc(retire_pc),.retire_insn(retire_insn),.retire_result(retire_result),.retire_rd(retire_rd),
 .fi_valid(inject_valid),.fi_target(4'd8),.fi_index(32'd0),.fi_mask(inject_mask),.fi_ack(fi_ack),
 .packet_fi_valid(1'b0),.packet_fi_target(2'd0),.packet_fi_index(32'd0),.packet_fi_mask(512'd0),.packet_fi_ack(packet_fi_ack),.packet_fatal(packet_fatal),.packet_irq(packet_irq),
 .event_valid(event_valid),.sticky_flags(sticky_flags),.corrected_count(corrected_count),.uncorrectable_count(uncorrectable_count),.disagreement_count(disagreement_count),.fatal_count(fatal_count),.first_pc(first_pc),.first_address(first_address),.first_flags(first_flags),.last_pc(last_pc),.last_address(last_address),.last_flags(last_flags));
 reg [7:0] input_bytes[0:4095],expected[0:4095];integer input_count,output_count,received=0,cycles=0,retired=0;
 wire out_valid,out_frame;wire [7:0] out_byte;
 riscue_uart_rx #(.CLOCK_HZ(1280000),.BAUD(10000)) observer(.clk(clk),.rst_n(rst_n),.rx(tx),.valid(out_valid),.data(out_byte),.framing_error(out_frame));
 task automatic send_byte(input [7:0] b);integer k;begin
  @(negedge clk);rx=0;repeat(128)@(negedge clk);
  for(k=0;k<8;k=k+1)begin rx=b[k];repeat(128)@(negedge clk);end
  rx=1;repeat(128)@(negedge clk);
 end endtask
 integer i,descriptor_address;bit descriptor_fault,ram_ded,ram_sec;ecc_result_t d;reg [31:0] stats_golden[0:7];
 initial begin
  descriptor_fault=$test$plusargs("descriptor_fault");ram_ded=$test$plusargs("ram_ded");ram_sec=$test$plusargs("ram_sec");
  if(descriptor_fault&&!$value$plusargs("descriptor_address=%d",descriptor_address))$fatal(1,"descriptor symbol required");
  if(!$value$plusargs("inputs=%d",input_count)||!$value$plusargs("outputs=%d",output_count))$fatal(1,"counts required");
  $readmemh("build/packet/input.hex",input_bytes);$readmemh("build/packet/output.hex",expected);
  repeat(4)@(negedge clk);rst_n=1;repeat(10000)@(negedge clk);
  if(descriptor_fault)begin d=ecc_decode(dut.ram.mem[descriptor_address/4]);dut.ram.mem[descriptor_address/4]=ecc_encode(d.data^1);end
  if(ram_sec||ram_ded)begin
   inject_valid=1;inject_mask=ram_ded?3:1;#1;if(!fi_ack)$fatal(1,"RAM FI rejected");
   @(negedge clk);inject_valid=0;
  end
  if(ram_ded)begin
   repeat(5000)@(negedge clk);
   if(!fatal||received!=0)$fatal(1,"RAM DED escaped containment");
   $display("PASS packet CPU RAM DED containment RF_TMR=%0d",RF_TMR);$finish;
  end
  if(descriptor_fault)begin
   for(i=0;i<11;i=i+1)send_byte(input_bytes[i]);repeat(20000)@(negedge clk);
   d=ecc_decode(dut.ram.mem[2037]);if(d.data!=1||received!=0)$fatal(1,"descriptor fault escaped");
   $display("PASS packet C corrupted descriptor rejected RF_TMR=%0d",RF_TMR);$finish;
  end
  // First batch followed by enough idle clocks to exercise partial-frame timeout.
  for(i=0;i<input_count;i=i+1)begin
   send_byte(input_bytes[i]);
   if(i==input_count/2-1)repeat(230000)@(negedge clk);
   // Allow response drain; no host backpressure or simultaneous TX assumptions.
   repeat(3000)@(negedge clk);
  end
  repeat(150000)@(negedge clk);
  stats_golden[0]=32'h5041434b;stats_golden[1]=3;stats_golden[2]=1;stats_golden[3]=1;
  stats_golden[4]=1;stats_golden[5]=0;stats_golden[6]=1;stats_golden[7]=1;
  for(i=0;i<8;i=i+1)begin d=ecc_decode(dut.ram.mem[2032+i]);
   if(d.uncorrectable||d.data!==stats_golden[i])$fatal(1,"stats[%0d] got=%h expected=%h",i,d.data,stats_golden[i]);end
  if(dut.uart.s.overflow!=0||dut.uart.s.framing!=0)$fatal(1,"UART unexpected loss");
  if(ram_sec&&corrected_count==0)$fatal(1,"missing SRAM correction telemetry");
  if(received!=output_count)$fatal(1,"response count %0d expected %0d",received,output_count);
  d=ecc_decode(dut.ram.mem[2032]);if(d.data!=32'h5041434b)$fatal(1,"missing ready mailbox");
  d=ecc_decode(dut.ram.mem[2033]);if(d.data<3)$fatal(1,"accepted packets missing");
  $display("PASS packet C UART RF_TMR=%0d cycles=%0d retired=%0d reply_bytes=%0d",RF_TMR,cycles,retired,received);$finish;
 end
 always @(negedge clk)if(rst_n)begin
  cycles=cycles+1;if(retire_valid)retired=retired+1;
  if((fatal&&!ram_ded)||packet_fatal||trap)$fatal(1,"unexpected CPU/peripheral fault pc=%h cause=%h",pc,trap_cause);
  if(out_frame)$fatal(1,"reply framing");
  if(out_valid)begin
   if(received>=output_count||out_byte!==expected[received])$fatal(1,"reply[%0d] got=%h expected=%h",received,out_byte,expected[received]);
   received=received+1;
  end
  if(cycles>3000000)$fatal(1,"simulation timeout");
 end
endmodule
