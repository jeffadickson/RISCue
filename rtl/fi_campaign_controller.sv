// Hardware-clocked fault campaign controller, descriptor capture and TMR repair.
module fi_campaign_controller #(parameter integer WORDS=1024,parameter bit RF_TMR=0)(
 input logic clk,rst_n,arm,request_toggle,core_reset,core_fatal,external_trigger,
 input logic [3:0] command_target,input logic [31:0] command_index,
 input logic [511:0] command_mask,
 input logic [31:0] command_delay,command_gap,command_index_step,command_trigger_pc,
 input logic [15:0] command_count,input logic [1:0] command_trigger_kind,
 input logic command_rotate,command_stop_on_fatal,
 input logic retire_valid,input logic [31:0] retire_pc,pc,input logic fi_ack,
 output logic fi_valid,output logic [3:0] fi_target,output logic [31:0] fi_index,
 output logic [511:0] fi_mask,output logic busy,done_toggle,
 output logic controller_disagreement,controller_error_sticky,
 output logic [7:0] status,output logic [15:0] accepted,attempted,
 output logic [31:0] last_pc,output logic [63:0] last_cycle,trigger_cycle
);
 import riscue_pipeline_pkg::*;
 localparam logic [7:0] BOOT=8'h00,IDLE=8'h0f,TRIGGER=8'h33,DELAY=8'h3c,FIRE=8'h55,GAP=8'h5a,DONE=8'h66;
 typedef struct packed {
  logic [7:0] state,status;
  logic token,done,error,rotate,stop;
  logic [3:0] target;logic [31:0] index;
  logic [511:0] mask;
  logic [31:0] delay,gap,step,trigger_pc,wait_count;
  logic [15:0] count,accepted,attempted;
  logic [1:0] trigger_kind;
  logic [63:0] cycle,last_cycle,trigger_cycle;
  logic [31:0] last_pc;
 } campaign_t;
 (* keep="true",DONT_TOUCH="TRUE" *) campaign_t c0,c1,c2;
 campaign_t s,n;
 integer width;logic bad_record,legal_target,legal_mask,legal_state,trigger_now;
 function automatic integer target_width(input [3:0] target,input [31:0] index);
  target_width=fi_width(RF_TMR,WORDS,target,index);
 endfunction
 always_comb begin
  s=(c0&c1)|(c0&c2)|(c1&c2);n=s;n.cycle=s.cycle+1;
  controller_disagreement=(c0!=c1)||(c0!=c2);
  bad_record=(c0!=c1)&&(c0!=c2)&&(c1!=c2);
  if(controller_disagreement)n.error=1;
  legal_state=s.state==BOOT||s.state==IDLE||s.state==TRIGGER||s.state==DELAY||s.state==FIRE||s.state==GAP||s.state==DONE;
  busy=s.state==TRIGGER||s.state==DELAY||s.state==FIRE||s.state==GAP;
  width=target_width(s.target,s.index);legal_target=width>0;legal_mask=s.mask!=0&&(s.mask>>width)==0;
  fi_valid=rst_n&&s.state==FIRE&&arm&&!core_reset&&request_toggle==s.token&&(!core_fatal||!s.stop)&&!bad_record&&legal_target&&legal_mask;
  fi_target=s.target;fi_index=s.index;fi_mask=s.mask;
  done_toggle=s.done;status=s.status;accepted=s.accepted;attempted=s.attempted;
  last_pc=s.last_pc;last_cycle=s.last_cycle;trigger_cycle=s.trigger_cycle;controller_error_sticky=s.error;
  trigger_now=(s.trigger_kind==0)||(s.trigger_kind==1&&retire_valid&&retire_pc==s.trigger_pc)||(s.trigger_kind==2&&external_trigger);
  if(bad_record||!legal_state)begin n.state=DONE;n.status=10;n.error=1;end
  else if(busy&&(!arm||core_reset||(core_fatal&&s.stop)||request_toggle!=s.token))begin
   n.state=DONE;n.status=!arm?6:core_reset?8:request_toggle!=s.token?9:7;
  end else case(s.state)
   BOOT:begin n.token=request_toggle;n.state=IDLE;end
   IDLE:if(request_toggle!=s.token)begin
    n.token=request_toggle;n.status=0;n.accepted=0;n.attempted=0;n.last_pc=0;n.last_cycle=0;n.trigger_cycle=0;
    n.target=command_target;n.index=command_index;n.mask=command_mask;
    n.delay=command_delay;n.gap=command_gap;n.step=command_index_step;n.count=command_count;
    n.trigger_kind=command_trigger_kind;n.trigger_pc=command_trigger_pc;
    n.rotate=command_rotate;n.stop=command_stop_on_fatal;
    if(!arm)begin n.state=DONE;n.status=1;end
    else if(target_width(command_target,command_index)==0)begin n.state=DONE;n.status=2;end
    else if(command_mask==0||(command_mask>>target_width(command_target,command_index))!=0)begin n.state=DONE;n.status=3;end
    else if(command_delay<1||command_gap<2||command_count==0||command_trigger_kind==3)begin n.state=DONE;n.status=4;end
    else n.state=TRIGGER;
   end
   TRIGGER:if(trigger_now)begin n.trigger_cycle=s.cycle;n.wait_count=s.delay-1;n.state=s.delay==1?FIRE:DELAY;end
   DELAY:if(s.wait_count==1)n.state=FIRE;else n.wait_count=s.wait_count-1;
   FIRE:begin
    n.attempted=s.attempted+1;
    if(!fi_ack)begin n.state=DONE;n.status=5;end
    else begin
     n.accepted=s.accepted+1;n.last_pc=pc;n.last_cycle=s.cycle;
     if(s.accepted+1==s.count)n.state=DONE;
     else begin
      n.index=s.index+s.step;
      if(s.rotate)begin n.mask=(s.mask>>1)|(s.mask[0]?(512'd1<<(width-1)):512'd0);end
      n.wait_count=s.gap-1;n.state=GAP;
     end
    end
   end
   GAP:if(!legal_target||!legal_mask)begin n.status=!legal_target?2:3;n.state=DONE;end
       else if(s.wait_count==1)n.state=FIRE;else n.wait_count=s.wait_count-1;
   DONE:begin n.done=~s.done;n.state=IDLE;end
   default:begin n.state=DONE;n.status=10;end
  endcase
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin c0<='0;c1<='0;c2<='0;end
  else begin c0<=n;c1<=n;c2<=n;end
 end
endmodule
