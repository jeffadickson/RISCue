// Two execution clocks for multiply; 32 divider iterations and a result clock.
module riscue_muldiv #(parameter bit FI_ENABLE=0)(
 input logic clk,rst_n,start,cancel,input logic [2:0] op,input logic [31:0] lhs,rhs,
 output logic ready,done,disagreement,fatal,output logic [31:0] result,
 input logic fi_valid,input logic [1:0] fi_replica,input logic [511:0] fi_mask,output logic fi_ack
);
 typedef riscue_pipeline_pkg::md_state_t state_t;
 (* keep="true",DONT_TOUCH="TRUE" *) state_t s0,s1,s2;
 state_t s,n;
 (* use_dsp="yes" *) wire signed [65:0] product_value=s.a*s.b;
 logic [32:0] shifted;logic [31:0] qnext;
 always_comb begin
  s=(s0&s1)|(s0&s2)|(s1&s2);n=s;n.done=0;
  disagreement=(s0!=s1)||(s0!=s2);ready=!s.busy&&!s.fatal;
  fatal=s.fatal||((s0!=s1)&&(s0!=s2)&&(s1!=s2));done=rst_n&&s.done&&!fatal;result=s.result;
  shifted={s.remainder[31:0],s.quotient[31]};qnext={s.quotient[30:0],1'b0};
  fi_ack=rst_n&&FI_ENABLE&&fi_valid&&fi_replica<3&&(fi_mask>>$bits(state_t))==0&&fi_mask!=0;
  if((s0!=s1)&&(s0!=s2)&&(s1!=s2))begin n.fatal=1;n.busy=0;n.done=0;end
  else if(cancel)begin n.busy=0;n.done=0;end
  else if(start&&ready)begin
   n.busy=1;n.op=op;n.count=0;n.original=lhs;n.remainder=0;
   n.qnegative=!op[0]&&(lhs[31]^rhs[31]);n.rnegative=!op[0]&&lhs[31];
   n.quotient=(!op[0]&&lhs[31])?(~lhs+32'd1):lhs;
   n.divisor=(!op[0]&&rhs[31])?(~rhs+32'd1):rhs;
   n.a=$signed({((op==1||op==2)&&lhs[31]),lhs});
   n.b=$signed({((op==1)&&rhs[31]),rhs});
  end else if(s.busy&&!s.fatal)begin
   if(!s.op[2])begin
    if(s.count==0)begin n.product=product_value;n.count=1;end
    else if(s.count==1)begin n.result=s.op==0?s.product[31:0]:s.product[63:32];n.busy=0;n.done=1;end
    else begin n.fatal=1;n.busy=0;end
   end else if(s.count<32)begin
    if(shifted>={1'b0,s.divisor})begin n.remainder=shifted-{1'b0,s.divisor};qnext[0]=1;end
    else n.remainder=shifted;
    n.quotient=qnext;n.count=s.count+1'b1;
   end else if(s.count==32)begin
    if(s.divisor==0)n.result=s.op[1]?s.original:32'hffffffff;
    else if(s.op[1])n.result=s.rnegative?(~s.remainder[31:0]+32'd1):s.remainder[31:0];
    else n.result=s.qnegative?(~s.quotient+32'd1):s.quotient;
    n.busy=0;n.done=1;
   end else begin n.fatal=1;n.busy=0;end
  end
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin s0<='0;s1<='0;s2<='0;end
  else begin
   s0<=n;s1<=n;s2<=n;
   if(fi_ack)case(fi_replica)
    0:s0<=n^fi_mask[$bits(state_t)-1:0];
    1:s1<=n^fi_mask[$bits(state_t)-1:0];
    2:s2<=n^fi_mask[$bits(state_t)-1:0];
   endcase
  end
 end
endmodule
