`timescale 1ns/1ps
module tb_debug;
 import ft_pkg::*;
 logic clk=0,rst_n=0,tck=0,tms=1,tdi=0,external_irq=0;
 wire tdo,debug_halted,fatal,trap,retire_valid;wire [31:0] pc,retire_pc,retire_insn;
 riscue_debug_soc dut(.*);
 always #5 clk=~clk;
 task automatic tick;@(posedge clk);#1;endtask
 task automatic wr(input [6:0] addr,input [31:0] data);
  @(negedge clk);force dut.dmi_valid=1;force dut.dmi_write=1;
  force dut.dmi_addr=addr;force dut.dmi_wdata=data;
  tick();@(negedge clk);release dut.dmi_valid;release dut.dmi_write;release dut.dmi_addr;release dut.dmi_wdata;
  tick();
 endtask
 task automatic halted;
  integer n;n=0;while(!debug_halted&&n<300)begin tick();n++;end
  if(!debug_halted)$fatal(1,"halt timeout");
 endtask
 task automatic regwrite(input [15:0] no,input [31:0] data);
  wr('h04,data);wr('h17,32'h00230000|no);repeat(3)tick();
  if(dut.dm.s.cmderr!=0)$fatal(1,"abstract command error %d",dut.dm.s.cmderr);
 endtask
 initial begin
  repeat(4)tick();rst_n=1;wr('h10,32'h80000001);halted();
  // Unsupported abstract size and postexec set sticky cmderr; no register write.
  wr('h17,32'h00331001);if(dut.dm.s.cmderr!=2)$fatal(1,"unsupported command accepted");
  wr('h16,32'h700);regwrite('h1001,32'h12345678);
  if(dut.core.rf[1]!=ecc_encode(32'h12345678))$fatal(1,"ECC not regenerated");
  // x0 remains hardwired zero.
  regwrite('h1000,32'hffffffff);if(dut.core.rf[0]!=ecc_encode(0))$fatal(1,"x0 changed");
  // Single replica in architectural debug state is corrected, cannot resume.
  @(negedge clk);force dut.core.c0.debug_halted=0;#1;
  if(!dut.core.disagreement_event||!debug_halted)$fatal(1,"core injection/vote failed");
  tick();release dut.core.c0.debug_halted;tick();
  if(!debug_halted||dut.core.c0!=dut.core.c1)$fatal(1,"debug state not repaired");
  // Single replica in DM run-control is corrected, cannot resume.
  @(negedge clk);force dut.dm.a='1;#1;
  if(!dut.dm.disagreement||!debug_halted)$fatal(1,"DM injection/vote failed");
  tick();release dut.dm.a;tick();
  if(!debug_halted||dut.dm.a!=dut.dm.b)$fatal(1,"DM state not repaired");
  // Misaligned SBA rejected without changing memory.
  wr('h38,32'h00140000);wr('h39,3);
  if(dut.dm.s.sb_error!=3||dut.sb_req)$fatal(1,"misaligned SBA accepted");
  wr('h38,32'h00047000);
  // Reset preserves DM connectivity; halt before the first retirement.
  wr('h10,32'h80000003);wr('h10,32'h80000001);halted();
  if(pc!=0||dut.core.s.minstret!=0)$fatal(1,"reset halt ran instructions");
  // Step an ECALL with a pending interrupt: trap first, stop at mtvec.
  @(negedge clk);dut.ram.mem[0]=ecc_encode(32'h00000073);
  regwrite('h305,32'h100);regwrite('h304,32'h800);regwrite('h300,32'h8);regwrite('h7b0,32'h8004);
  external_irq=1;repeat(4)tick();wr('h10,32'h40000001);halted();
  if(pc!='h100||dut.core.s.mcause!=11||dut.core.s.debug_cause!=4)$fatal(1,"step trap priority wrong");
  // A fatal integrity event remains unavailable, never becomes a resumable halt.
  @(negedge clk);dut.core.c0.fatal=1;dut.core.c1.fatal=1;tick();
  wr('h10,32'h40000001);repeat(5)tick();
  if(!fatal||debug_halted||dut.core.req)$fatal(1,"fatal resumed");
  // No complete DM majority latches failure even after voted state is repaired.
  rst_n=0;repeat(3)tick();rst_n=1;wr('h10,32'h80000001);halted();
  @(negedge clk);force dut.dm.a='1;force dut.dm.b='0;force dut.dm.c=185'h12345;#1;
  if(!dut.dm.bad)$fatal(1,"fault injection did not activate majority detector");
  tick();release dut.dm.a;release dut.dm.b;release dut.dm.c;repeat(3)tick();
  if(!dut.dm.fault||!fatal)$fatal(1,"DM majority loss did not latch: fault=%b fatal=%b failed=%b",dut.dm.fault,fatal,dut.dm.s.failed);
  wr('h10,0);if(!dut.dm.fault)$fatal(1,"dmactive cleared an integrity failure");
  $display("PASS debug directed: command errors, x0, ECC write, TMR repair, SBA alignment, reset halt, step trap/IRQ, fatal containment, sticky DM majority loss");$finish;
 end
 initial begin #200000;$fatal(1,"test timeout");end
endmodule
