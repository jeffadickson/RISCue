`timescale 1ns/1ps
module tb_packet_uart;
 import ft_pkg::*;
 logic clk=0,rst_n=0,rx=1,req=0;wire tx,ready,error,irq,fatal,corrected_event,disagreement_event,fi_ack;
 logic [38:0] addr_code,wdata_code,ctrl_code;wire [38:0] rdata_code;
 logic fi_valid=0;logic [1:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 riscue_packet_uart #(.CLOCK_HZ(80000),.BAUD(10000),.DEPTH(4),.FI_ENABLE(1)) dut(.*);
 always #5 clk=~clk;
 task automatic reset;begin req=0;fi_valid=0;rst_n=0;repeat(3)@(negedge clk);rst_n=1;end endtask
 task automatic serial(input [7:0] b);integer k;begin rx=0;repeat(8)@(negedge clk);for(k=0;k<8;k=k+1)begin rx=b[k];repeat(8)@(negedge clk);end rx=1;repeat(12)@(negedge clk);end endtask
 task automatic access(input bit wr,input [7:0] off,input [31:0] value,input bit expect_error,output [31:0] result);
 ecc_result_t d;integer timeout;begin
  @(negedge clk);addr_code=ecc_encode(32'h10000000+off);wdata_code=ecc_encode(value);ctrl_code=ecc_encode(wr?32'h1f:0);req=1;timeout=0;
  while(!ready)begin @(negedge clk);timeout=timeout+1;if(timeout>20)$fatal(1,"MMIO timeout");end
  d=ecc_decode(rdata_code);result=d.data;if(error!==expect_error||d.uncorrectable)$fatal(1,"MMIO response off=%h",off);
  repeat(3)@(negedge clk);req=0;repeat(2)@(negedge clk);
 end endtask
 task automatic inject(input [1:0] target,input [31:0] index,input [511:0] mask);begin
  @(negedge clk);fi_valid=1;fi_target=target;fi_index=index;fi_mask=mask;#1;if(!fi_ack)$fatal(1,"FI rejected");@(negedge clk);fi_valid=0;
 end endtask
 reg [31:0] v;integer k;
 initial begin
  reset();access(1,12,1,0,v);serial(8'h5a);if(!irq)$fatal(1,"missing RX IRQ");
  inject(0,0,1);access(0,4,0,0,v);if(v!=8'h5a)$fatal(1,"SEC correction");
  access(0,24,0,0,v);if(v!=1)$fatal(1,"correction counter");
  access(0,4,0,1,v); // held request above must not pop twice
  inject(2,0,1);repeat(3)@(negedge clk);if(fatal||dut.s0!==dut.s1)$fatal(1,"TMR repair");
  access(1,16,32'hffffffff,0,v);for(k=49;k<=57;k=k+1)access(1,20,k,0,v);
  access(0,16,0,0,v);if((v^32'hffffffff)!=32'hcbf43926)$fatal(1,"CRC golden vector");
  access(1,4,0,1,v);access(0,3,0,1,v);
  reset();force dut.tx_ready=0;
  access(1,8,32'h5a,0,v);inject(1,0,1);release dut.tx_ready;
  repeat(100)@(negedge clk);access(0,24,0,0,v);if(v!=1||fatal)$fatal(1,"TX SEC correction");
  reset();force dut.tx_ready=0;access(1,8,32'h5a,0,v);inject(1,0,3);release dut.tx_ready;
  repeat(3)@(negedge clk);if(!fatal||dut.send)$fatal(1,"TX DED escaped");
  reset();rx=0;repeat(90)@(negedge clk);rx=1;repeat(100)@(negedge clk);
  access(0,28,0,0,v);if(v==0)$fatal(1,"missing framing count");
  reset();for(k=0;k<5;k=k+1)serial(k);access(0,32,0,0,v);if(v!=1)$fatal(1,"overflow count");
  reset();serial(8'h77);inject(0,0,3);access(0,4,0,1,v);if(!fatal)$fatal(1,"DED not fatal");
  reset();access(1,36,20,0,v);repeat(30)@(negedge clk);if(!fatal)$fatal(1,"watchdog not fatal");
  reset();@(negedge clk);dut.s0=dut.s0^1;dut.s1=dut.s1^2;#1;if(!fatal)$fatal(1,"majority loss not fatal");
  $display("PASS packet UART CRC, RX IRQ, held MMIO, SEC, DED, TMR, overflow, watchdog, majority loss");$finish;
 end
endmodule
