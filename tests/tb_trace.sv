module tb_trace;
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire halted,fatal,trap,ce,de,rv;wire [31:0] cause,tval,pc,rpc,ri,rr;wire [4:0] rd;
 rv32im_ft_soc #(.WORDS(512),.INIT_FILE("build/program.hex")) dut(.clk(clk),.rst_n(rst_n),.halted(halted),.fatal(fatal),.trap(trap),.trap_cause(cause),.trap_value(tval),.pc(pc),.corrected_event(ce),.disagreement_event(de),.retire_valid(rv),.retire_pc(rpc),.retire_insn(ri),.retire_result(rr),.retire_rd(rd),.fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0));
 integer fd,n,rc,cycles;logic [31:0] epc,ei,erd,ev;logic [31:0] regs[0:31];ecc_result_t d;
 always @(posedge clk)if(rst_n&&rv)begin
  rc=$fscanf(fd,"%h %h %h %h\n",epc,ei,erd,ev);
  if(rc!=4||rpc!==epc||ri!==ei||rd!==erd[4:0]||rr!==ev)$fatal(1,"trace %0d pc=%h/%h ins=%h/%h rd=%d/%d value=%h/%h",n,rpc,epc,ri,ei,rd,erd,rr,ev);
  n=n+1;
 end
 initial begin
  fd=$fopen("build/program.trace","r");if(!fd)$fatal(1,"trace missing");$readmemh("build/program.regs",regs);n=0;cycles=0;
  repeat(2)@(negedge clk);rst_n=1;
  while(!halted&&cycles<3000)begin @(negedge clk);cycles=cycles+1;end
  if(!halted||fatal||!trap||cause!=3)$fatal(1,"trace termination %h",cause);
  rc=$fscanf(fd,"%h %h %h %h\n",epc,ei,erd,ev);if(rc==4)$fatal(1,"trace not exhausted");
  for(integer i=0;i<32;i=i+1)begin d=ecc_decode(dut.core.rf[i]);if(d.data!==regs[i])$fatal(1,"final x%0d mismatch",i);end
  $display("PASS differential program: %0d retirement records and all 32 registers, %0d cycles",n,cycles);$finish;
 end
 initial begin #40000;$fatal(1,"trace timeout");end
endmodule
