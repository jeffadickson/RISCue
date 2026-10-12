module formal_injector(input clk);
 logic [2:0] reset_age=0;
 wire rst_n=reset_age>=2;
 always @(posedge clk)if(reset_age<3)reset_age<=reset_age+1;
 (* anyseq *) logic arm,request_toggle,core_reset,core_fatal,external_trigger;
 (* anyseq *) logic [3:0] command_target;
 (* anyseq *) logic [31:0] command_index,command_delay,command_gap,command_index_step,command_trigger_pc;
 (* anyseq *) logic [511:0] command_mask;
 (* anyseq *) logic [15:0] command_count;
 (* anyseq *) logic [1:0] command_trigger_kind;
 (* anyseq *) logic command_rotate,command_stop_on_fatal,retire_valid;
 (* anyseq *) logic [31:0] retire_pc,pc;
 wire fi_valid;wire fi_ack=fi_valid;
 wire [3:0] fi_target;wire [31:0] fi_index;wire [511:0] fi_mask;
 wire busy,done_toggle,controller_disagreement,controller_error_sticky;
 wire [7:0] status;wire [15:0] accepted,attempted;wire [31:0] last_pc;
 wire [63:0] last_cycle,trigger_cycle;
 fi_campaign_controller dut(.*);
 reg past_valid=0;
 always @(posedge clk)begin
  past_valid<=1;
  if(rst_n)begin
   assert(accepted<=attempted);
   if(fi_valid)begin
    assert(arm&&!core_reset);
    assert(riscue_pipeline_pkg::fi_width(0,1024,fi_target,fi_index)>0);
    assert(fi_mask!=0&&(fi_mask>>riscue_pipeline_pkg::fi_width(0,1024,fi_target,fi_index))==0);
   end
   if(past_valid&&$past(rst_n&&fi_valid))assert(!fi_valid);
   cover(accepted==3&&status==0);
  end
 end
endmodule
