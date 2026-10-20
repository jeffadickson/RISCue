`timescale 1ns/1ps
module tb_multicycle_faults;
 import ft_pkg::*;import riscue_pipeline_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 logic fi_valid=0;logic [3:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 wire fatal,req,fi_ack,disagreement;integer checked=0,invalid=0;
 riscue_pipeline_core #(.MULTICYCLE(1),.PIPELINE_PROTECTION(0),.FI_ENABLE(1)) dut(
  .clk(clk),.rst_n(rst_n),.external_irq(1'b0),.ready(1'b1),.bus_error(1'b0),.external_fault(1'b0),
  .rdata_code(ecc_encode(32'h0000006f)),.fatal(fatal),.req(req),.fi_valid(fi_valid),.fi_target(fi_target),
  .fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(fi_ack),.disagreement_event(disagreement),
  .debug_haltreq(1'b0),.debug_resumereq(1'b0),.debug_reg_valid(1'b0),.debug_reg_write(1'b0),
  .debug_regno(16'b0),.debug_wdata(32'b0),.halt_request(1'b0),.boot_pc(32'b0));
 task reset_core;
  rst_n=0;fi_valid=0;repeat(3)@(negedge clk);rst_n=1;@(negedge clk);
 endtask
 initial begin
  reset_core();
  for(integer replica=0;replica<3;replica=replica+1)
   for(integer bitno=0;bitno<$bits(compact_state_t);bitno=bitno+1)begin
    fi_target=5+replica;fi_index=bitno/512;fi_mask=512'b1<<(bitno%512);fi_valid=1;
    #1;if(!fi_ack)$fatal(1,"compact FI ABI rejected valid bit %d",bitno);
    @(negedge clk);fi_valid=0;#1;
    if(fatal||!disagreement)$fatal(1,"single replica upset was not masked/reported %d/%d",replica,bitno);
    @(negedge clk);#1;
    if(dut.impl.compact0!==dut.impl.compact1||dut.impl.compact0!==dut.impl.compact2)
     $fatal(1,"compact replica not repaired %d/%d",replica,bitno);
    checked=checked+1;
   end
  fi_valid=1;fi_index=($bits(compact_state_t)+511)/512;#1;
  if(fi_ack)$fatal(1,"out-of-range compact FI index accepted");fi_valid=0;
  for(integer code=0;code<256;code=code+1)begin
   if(code!=0&&code!=15&&code!=51&&code!=60&&code!=85&&code!=90)begin
    reset_core();
    dut.impl.compact0.phase=code;dut.impl.compact1.phase=code;dut.impl.compact2.phase=code;
    #1;if(!fatal||req)$fatal(1,"illegal compact phase permits issue %h",code);
    @(negedge clk);#1;if(!fatal)$fatal(1,"compact fatal not sticky");
    invalid=invalid+1;
   end
  end
  $display("PASS compact state: %0d single-bit replica upsets repaired; %0d unused phases fail closed",checked,invalid);$finish;
 end
 initial begin #1000000;$fatal(1,"compact fault test timeout");end
endmodule
