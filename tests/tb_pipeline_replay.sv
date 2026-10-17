`timescale 1ns/1ps
module tb_pipeline_replay #(parameter bit RF_TMR=0, parameter integer SCENARIO=0);
 import riscue_pipeline_pkg::*;
 state_t damage;
 logic injected=0;
 integer replay_seen=0;
 integer illegal_code=1;
 initial if($value$plusargs("illegal=%d",illegal_code))begin end
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire fatal,retire_valid,trap;
 wire [31:0] pc,trap_cause,retire_pc,retire_result;
 wire [4:0] retire_rd;
 integer cycles=0,retired=0;logic saw_trap=0;
 logic [31:0] image[0:1023];
 riscue_pipeline_soc #(.WORDS(1024),.BUS_TIMEOUT(32),.RF_TMR(RF_TMR)) dut(
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
  for(integer k=0;k<1024;k=k+1)dut.ram.mem[k]=ecc_encode(image[k]);
  rst_n=1;
  while(cycles<2000)begin
   @(negedge clk);cycles=cycles+1;
   if(dut.core.impl.recovery.attempts!=0)replay_seen=1;
   if(fatal&&(SCENARIO==2||SCENARIO==3||SCENARIO==4||SCENARIO==6||SCENARIO==9))begin
    if(!injected)$fatal(1,"unexpected fatal before injection");
    repeat(5)begin @(negedge clk);if(!fatal||dut.core.req)$fatal(1,"fail-stop not sticky");end
    $display("PASS parity fail-stop scenario=%0d",SCENARIO);$finish;
   end
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
      check(11,99);if((SCENARIO==1||SCENARIO==5||SCENARIO==7||SCENARIO==10||SCENARIO==11)&&(!injected||!replay_seen))$fatal(1,"replay not exercised");if(!saw_trap||retired!=20)$fatal(1,"missing trap or retirement");
      $display("PASS pipeline replay RF_TMR=%d: %d retirements in %d clocks",RF_TMR,retired,cycles);$finish;
     end
     default:$fatal(1,"unexpected retirement PC %h",retire_pc);
    endcase
   end
  end
  $fatal(1,"pipeline timeout pc=%h retired=%d",pc,retired);
 end
 initial begin
  wait(rst_n);
  if(SCENARIO==1)begin
   wait(dut.core.impl.s.d.valid&&!dut.core.impl.recovery.unsafe_memory);
   @(negedge clk);damage='0;damage.d.insn=1;
   dut.core.impl.c0=dut.core.impl.c0^damage;injected=1;
  end else if(SCENARIO==2)begin
   wait(dut.core.impl.recovery.unsafe_memory);
   @(negedge clk);damage='0;damage.m.e.we=1;
   dut.core.impl.c0=dut.core.impl.c0^damage;injected=1;
  end else if(SCENARIO==4)begin
   wait(dut.core.impl.s.d.valid&&!dut.core.impl.recovery.unsafe_memory);
   @(negedge clk);dut.core.impl.replay0.attempts=3;dut.core.impl.replay1.attempts=3;dut.core.impl.replay2.attempts=3;
   damage='0;damage.d.insn=1;dut.core.impl.c0=dut.core.impl.c0^damage;injected=1;
  end else if(SCENARIO==5||SCENARIO==6)begin
   wait(dut.core.impl.s.bus_active&&!dut.core.impl.s.bus_data);
   @(negedge clk);force dut.core.ready=0;
   damage='0;damage.f.raw=1;dut.core.impl.c0=dut.core.impl.c0^damage;injected=1;
   repeat(5)begin @(negedge clk);if(!dut.core.req||dut.core.impl.recovery.phase!=5'b00111)$fatal(1,"fetch was not held during drain");end
   if(SCENARIO==5)release dut.core.ready;
  end else if(SCENARIO==7)begin
   wait(dut.core.impl.s.d.valid&&!dut.core.impl.recovery.unsafe_memory);
   @(negedge clk);dut.core.impl.payload_parity=dut.core.impl.payload_parity^5'b01000;injected=1;
  end else if(SCENARIO==8)begin
   @(negedge clk);dut.core.impl.replay0.phase=5'b00001;injected=1;
   #1;if(!dut.core.impl.disagreement_event)$fatal(1,"controller disagreement not reported");
   @(negedge clk);if(dut.core.impl.replay0!=dut.core.impl.replay1||dut.core.impl.replay1!=dut.core.impl.replay2)$fatal(1,"controller replica was not repaired");
  end else if(SCENARIO==9)begin
   @(negedge clk);dut.core.impl.replay0.phase=5'b00001;dut.core.impl.replay1.phase=5'b00010;dut.core.impl.replay2.phase=5'b00100;injected=1;
  end else if(SCENARIO==10)begin
   wait(dut.core.impl.s.d.valid&&!dut.core.impl.recovery.unsafe_memory);
   @(negedge clk);damage='0;damage.d.valid=1;dut.core.impl.c0=dut.core.impl.c0^damage;injected=1;
  end else if(SCENARIO==11)begin
   wait(dut.core.impl.s.w.valid&&!dut.core.impl.recovery.unsafe_memory);
   @(negedge clk);damage='0;damage.w.e.result=1;dut.core.impl.c0=dut.core.impl.c0^damage;injected=1;
  end else if(SCENARIO==3)begin
   @(negedge clk);dut.core.impl.replay0.phase=5'(illegal_code);dut.core.impl.replay1.phase=5'(illegal_code);dut.core.impl.replay2.phase=5'(illegal_code);injected=1;
  end
 end
endmodule
