`timescale 1ns/1ps
module tb_pipeline_smoke #(parameter bit RF_TMR=0);
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire fatal,retire_valid,trap;
 wire [31:0] pc,trap_cause,retire_pc,retire_result;
 wire [4:0] retire_rd;
 integer cycles=0,retired=0;logic saw_trap=0;
 logic [31:0] image[0:1023];
 riscue_pipeline_soc #(.WORDS(1024),.RF_TMR(RF_TMR)) dut(
  .clk(clk),.rst_n(rst_n),.external_irq(1'b0),.fatal(fatal),.trap(trap),.pc(pc),.trap_cause(trap_cause),
  .retire_valid(retire_valid),.retire_pc(retire_pc),.retire_rd(retire_rd),.retire_result(retire_result),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0));
 function automatic [31:0] csr(input [11:0] addr,input [4:0] rd,rs,input [2:0] f);
  csr={addr,rs,f,rd,7'h73};
 endfunction
 task automatic check(input [4:0] rd,input [31:0] value);
  if(retire_rd!==rd||retire_result!==value)$fatal(1,"pc=%h rd=%d result=%h expected rd=%d value=%h",retire_pc,retire_rd,retire_result,rd,value);
 endtask
 initial begin
  for(integer k=0;k<1024;k=k+1)image[k]=0;
  image[0]=32'h00700093;image[1]=32'h00300113;
  image[2]=32'h022081b3;image[3]=32'h0220c233;image[4]=32'h0220e2b3;
  image[5]=32'h30302023;image[6]=32'h30002303;image[7]=32'h001303b3;
  image[8]=32'h0493440d;image[9]=32'h00010044;
  image[10]=32'h10000513;image[11]=csr(12'h305,0,10,1);
  image[12]=32'h00000073;image[13]=32'h06300593;image[14]=32'h0000006f;
  image[64]=csr(12'h342,20,0,2);image[65]=csr(12'h341,21,0,2);
  image[66]=32'h004a8a93;image[67]=csr(12'h341,0,21,1);image[68]=32'h30200073;
  repeat(3)@(negedge clk);
  for(integer k=0;k<1024;k=k+1)begin
`ifdef RISCUE_PLAIN_MEMORY
 dut.plain.mem[k]=image[k];
`else
 dut.ram.mem[k]=ecc_encode(image[k]);
`endif
 end;
  rst_n=1;
  while(cycles<2000)begin
   @(negedge clk);cycles=cycles+1;
   if(fatal)$fatal(1,"hardware fatal at cycle %d pc=%h",cycles,pc);
   if(trap)begin if(trap_cause!=11)$fatal(1,"unexpected trap %d",trap_cause);saw_trap=1;end
   if(retire_valid)begin
    retired=retired+1;
    case(retire_pc)
     0:check(1,7);4:check(2,3);8:check(3,21);12:check(4,2);16:check(5,1);
     20:check(0,0);24:check(6,21);28:check(7,28);32:check(8,3);34:check(9,7);
     38:check(0,0);40:check(10,256);44:check(0,0);48:check(0,0);
     256:check(20,11);260:check(21,48);264:check(21,52);268:check(0,0);272:check(0,0);
     52:begin
      check(11,99);if(!saw_trap||retired!=20)$fatal(1,"missing trap or retirement");
`ifdef RISCUE_PLAIN_MEMORY
      dut.plain.core.impl.rf[30]=39'h1;
      dut.plain.mem[1000]=32'h1;
      repeat(40)@(negedge clk);
      if(dut.plain.core.impl.rf[30]!==39'h1||dut.plain.mem[1000]!==32'h1)
       $fatal(1,"PLAIN unexpectedly corrected a raw RF/RAM upset");
      if(dut.plain.core.impl.c1!=='0||dut.plain.core.impl.c2!=='0||
         dut.plain.core.impl.arithmetic0.s1!=='0||dut.plain.core.impl.arithmetic0.s2!=='0)
       $fatal(1,"PLAIN retained changing replica state");
      if(dut.corrected_event||dut.disagreement_event)$fatal(1,"PLAIN emitted mitigation event");
      $display("PASS PLAIN: raw RF/RAM upsets persist without correction");
`endif
      $display("PASS pipeline smoke RF_TMR=%d: %d retirements in %d clocks",RF_TMR,retired,cycles);$finish;
     end
     default:$fatal(1,"unexpected retirement PC %h",retire_pc);
    endcase
   end
  end
  $fatal(1,"pipeline timeout pc=%h retired=%d",pc,retired);
 end
endmodule
