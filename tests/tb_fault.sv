module tb_fault;
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire halted,fatal,trap,ce,de,rv;wire [31:0] cause,tval,pc,rpc,ri,rr;wire [4:0] rd;
 rv32im_ft_soc #(.WORDS(64),.BUS_TIMEOUT(12)) dut(.clk(clk),.rst_n(rst_n),.halted(halted),.fatal(fatal),.trap(trap),.trap_cause(cause),.trap_value(tval),.pc(pc),.corrected_event(ce),.disagreement_event(de),.retire_valid(rv),.retire_pc(rpc),.retire_insn(ri),.retire_result(rr),.retire_rd(rd),.fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0));
 ecc_result_t d;integer bitno,replica,n,campaign;logic [38:0] clean;logic seen;
 task boot;begin
  rst_n=0;for(integer j=0;j<64;j=j+1)dut.ram.mem[j]=ecc_encode(0);
  dut.ram.mem[0]=ecc_encode(32'h0000006f); // JAL x0,0
  repeat(2)@(negedge clk);rst_n=1;
 end endtask
 task expect_fault(input logic [31:0] expected);begin
  n=0;while(!halted&&n<100)begin @(negedge clk);n=n+1;end
  if(!halted||!fatal||cause!=expected)$fatal(1,"fault cause=%h expected=%h halted=%b",cause,expected,halted);
 end endtask
 initial begin
  campaign=0;
  // Every bit of each control replica, including PC, FSM, pending transaction and watchdog.
  for(replica=0;replica<3;replica=replica+1)for(bitno=0;bitno<$bits(control_t);bitno=bitno+1)begin
   boot();
   case(replica)
    0:dut.core.c0=dut.core.c0^(control_t'(1)<<bitno);
    1:dut.core.c1=dut.core.c1^(control_t'(1)<<bitno);
    2:dut.core.c2=dut.core.c2^(control_t'(1)<<bitno);
   endcase
   #1;if(!de)$fatal(1,"TMR disagreement not reported");
   @(negedge clk);if(fatal||dut.core.c0!==dut.core.c1||dut.core.c1!==dut.core.c2)$fatal(1,"TMR repair %0d %0d",replica,bitno);
   campaign=campaign+1;
  end
  // Every RF code bit, including ECC parity bits, repaired by background scrub.
  for(bitno=0;bitno<39;bitno=bitno+1)begin
   boot();clean=ecc_encode(32'h12345678);dut.core.rf[20]=clean^(39'b1<<bitno);seen=0;
   repeat(40)begin @(negedge clk);if(ce)seen=1;end
   if(fatal||dut.core.rf[20]!==clean||!seen)$fatal(1,"RF correction bit %0d",bitno);
   campaign=campaign+1;
  end
  // Instruction correction and fetch integrity rejection.
  boot();dut.ram.mem[0]=ecc_encode(32'h0000006f)^39'd1;
  repeat(12)@(negedge clk);if(fatal||dut.ram.mem[0]!==ecc_encode(32'h0000006f))$fatal(1,"instruction repair");
  boot();dut.ram.mem[0]=ecc_encode(32'h0000006f)^39'd3;expect_fault(32'h80000002);
  boot();dut.core.rf[20]=ecc_encode(32'h12345678)^39'd3;expect_fault(32'h80000003);
  // Execution transient is caught before the instruction writes x1.
  boot();dut.ram.mem[0]=ecc_encode(32'h00500093);
  while(dut.core.voted.state!=ST_EXEC)@(negedge clk);
  force dut.core.e1='0;
  #1;if(rv)$fatal(1,"bad result permitted to retire");
  @(negedge clk);release dut.core.e1;expect_fault(32'h80000004);
  d=ecc_decode(dut.core.rf[1]);if(d.data!=0)$fatal(1,"bad result committed");
  // Two-replica illegal state is detected, not silently executed.
  boot();dut.core.c0.state=8'h01;dut.core.c1.state=8'h01;expect_fault(32'h80000001);
  boot();force dut.ready=0;expect_fault(32'h80000005);release dut.ready;
  // Memory background scrub DED escalates to the core.
  boot();dut.ram.mem[12]=ecc_encode(32'habcd)^39'd3;expect_fault(32'h80000006);
  $display("PASS faults: %0d exhaustive single-bit control/RF injections + 7 directed containment cases",campaign);$finish;
 end
 initial begin #2000000;$fatal(1,"fault test timeout");end
endmodule
