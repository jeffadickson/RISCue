`timescale 1ns/1ps
module tb_injector;
 logic clk=0,rst_n=0,arm=0,request_toggle=0,core_reset=0,core_fatal=0,external_trigger=0;
 logic [3:0] command_target=8;logic [31:0] command_index=100;
 logic [511:0] command_mask=1;
 logic [31:0] command_delay=2,command_gap=4,command_index_step=1,command_trigger_pc=0;
 logic [15:0] command_count=3;logic [1:0] command_trigger_kind=0;
 logic command_rotate=1,command_stop_on_fatal=1,retire_valid=0;
 logic [31:0] retire_pc=0,pc=32'h100;
 wire fi_valid;wire fi_ack=fi_valid;wire [3:0] fi_target;wire [31:0] fi_index;
 wire [511:0] fi_mask;wire busy,done_toggle,controller_disagreement,controller_error_sticky;
 wire [7:0] status;wire [15:0] accepted,attempted;wire [31:0] last_pc;
 wire [63:0] last_cycle,trigger_cycle;
 integer edges=0,pulses=0,previous=-1;
 always #5 clk=~clk;
 fi_campaign_controller dut(.*);
 always @(posedge clk)if(rst_n)begin
  edges=edges+1;
  if(fi_valid)begin
   if(pulses>0&&edges-previous!=4)$fatal(1,"incorrect gap");
   if(fi_index!=100+pulses)$fatal(1,"incorrect stride");
   if(fi_mask!=(512'd1<<(pulses==0?0:39-pulses)))$fatal(1,"incorrect rotation");
   previous=edges;pulses=pulses+1;
  end
 end
 initial begin
  repeat(3)@(negedge clk);rst_n=1;repeat(3)@(negedge clk);arm=1;request_toggle=1;
  repeat(30)@(negedge clk);
  if(accepted!=3||attempted!=3||status!=0||pulses!=3||!done_toggle)$fatal(1,"burst failed");
  if(last_cycle-trigger_cycle!=10)$fatal(1,"first delay or timestamp wrong");
  command_mask=512'd1<<40;request_toggle=0;
  repeat(8)@(negedge clk);if(status!=3||accepted!=0||pulses!=3)$fatal(1,"bad mask accepted");
  command_mask=1;command_trigger_kind=2;request_toggle=1;
  repeat(8)@(negedge clk);if(!busy||pulses!=3)$fatal(1,"trigger wait failed");arm=0;
  repeat(8)@(negedge clk);if(status!=6||busy||pulses!=3)$fatal(1,"disarm failed");
  rst_n=0;repeat(3)@(negedge clk);rst_n=1;arm=1;repeat(8)@(negedge clk);
  if(busy||pulses!=3)$fatal(1,"reset replayed a job");
  $display("PASS hardware injection scheduler");$finish;
 end
endmodule
