// Pure combinational RV32IM + Zbb/Zbc/Zbs semantics. Two instances are compared before use.
module riscue_execute #(parameter bit COMPRESSED=0, MULTICYCLE_M=0)(input logic [2:0] instruction_bytes,input logic [31:0] insn,pc,a,b,output ft_pkg::exec_t out);
 import ft_pkg::*;
 logic [6:0] op,f7;logic [2:0] f3;logic [31:0] ii,is_,ib,iu,ij,operand,target;
 logic branch;logic signed [63:0] ss;logic signed [65:0] su;logic [63:0] uu;
 // Result bit 32 marks an exact RV32 bitmanip encoding. No added state;
 // this function is synthesized separately inside each compared execution lane.
 function automatic [32:0] bitmanip(input logic [31:0] inst,x,y);
  logic [31:0] v; logic [63:0] polynomial; logic found;
  logic [4:0] sh; integer k,count;
  begin
   v=0;found=1;polynomial=0;count=0;
   sh=(inst[6:0]==7'h13)?inst[24:20]:y[4:0];
   if(inst[6:0]==7'h33) begin
    case({inst[31:25],inst[14:12]})
     {7'h20,3'd7}:v=x&~y;
     {7'h20,3'd6}:v=x|~y;
     {7'h20,3'd4}:v=~(x^y);
     {7'h05,3'd4}:v=($signed(x)<$signed(y))?x:y;
     {7'h05,3'd5}:v=(x<y)?x:y;
     {7'h05,3'd6}:v=($signed(x)>$signed(y))?x:y;
     {7'h05,3'd7}:v=(x>y)?x:y;
     {7'h04,3'd4}:begin v={16'd0,x[15:0]};found=(inst[24:20]==0);end
     {7'h30,3'd1}:v=(sh==0)?x:((x<<sh)|(x>>(32-sh)));
     {7'h30,3'd5}:v=(sh==0)?x:((x>>sh)|(x<<(32-sh)));
     {7'h24,3'd1}:v=x&~(32'd1<<sh);
     {7'h24,3'd5}:v={31'd0,x[sh]};
     {7'h34,3'd1}:v=x^(32'd1<<sh);
     {7'h14,3'd1}:v=x|(32'd1<<sh);
     {7'h05,3'd1},{7'h05,3'd2},{7'h05,3'd3}:begin
      for(k=0;k<32;k=k+1) if(y[k])polynomial=polynomial^({32'd0,x}<<k);
      case(inst[14:12])
       1:v=polynomial[31:0];2:v=polynomial[62:31];3:v=polynomial[63:32];
       default:v=0;
      endcase
     end
     default:found=0;
    endcase
   end else if(inst[6:0]==7'h13)begin
    case({inst[31:25],inst[14:12]})
     {7'h30,3'd5}:v=(sh==0)?x:((x>>sh)|(x<<(32-sh)));
     {7'h24,3'd1}:v=x&~(32'd1<<sh);
     {7'h24,3'd5}:v={31'd0,x[sh]};
     {7'h34,3'd1}:v=x^(32'd1<<sh);
     {7'h14,3'd1}:v=x|(32'd1<<sh);
     default:begin
      case({inst[31:20],inst[14:12]})
       {12'h600,3'd1}:begin
        count=32;for(k=0;k<32;k=k+1)if(x[k])count=31-k;v=count;
       end
       {12'h601,3'd1}:begin
        count=32;for(k=31;k>=0;k=k-1)if(x[k])count=k;v=count;
       end
       {12'h602,3'd1}:begin
        count=0;for(k=0;k<32;k=k+1)count=count+x[k];v=count;
       end
       {12'h604,3'd1}:v={{24{x[7]}},x[7:0]};
       {12'h605,3'd1}:v={{16{x[15]}},x[15:0]};
       {12'h287,3'd5}:for(k=0;k<4;k=k+1)v[k*8+:8]=(|x[k*8+:8])?8'hff:8'h00;
       {12'h698,3'd5}:v={x[7:0],x[15:8],x[23:16],x[31:24]};
       default:found=0;
      endcase
     end
    endcase
   end else found=0;
   bitmanip={found,v};
  end
 endfunction
 logic [32:0] bm;
 // Exhaustive input sensitivity avoids simulator sensitivity to function temporaries.
 always @(insn or pc or a or b or instruction_bytes) begin
  bm=bitmanip(insn,a,b);
  op=insn[6:0];f3=insn[14:12];f7=insn[31:25];
  ii={{20{insn[31]}},insn[31:20]};is_={{20{insn[31]}},insn[31:25],insn[11:7]};
  ib={{19{insn[31]}},insn[31],insn[7],insn[30:25],insn[11:8],1'b0};
  iu={insn[31:12],12'd0};ij={{11{insn[31]}},insn[31],insn[19:12],insn[20],insn[30:21],1'b0};
  out='0;out.rd=insn[11:7];out.next_pc=pc+(COMPRESSED?instruction_bytes:4);operand=0;target=0;branch=0;
  ss=$signed({{32{a[31]}},a})*$signed({{32{b[31]}},b});
  su=$signed({{34{a[31]}},a})*$signed({34'd0,b});uu={32'd0,a}*{32'd0,b};
  case(op)
   7'h37:begin out.rd_we=1;out.result=iu;end
   7'h17:begin out.rd_we=1;out.result=pc+iu;end
   7'h6f:begin out.rd_we=1;out.result=pc+(COMPRESSED?instruction_bytes:4);out.next_pc=pc+ij;end
   7'h67:begin if(f3!=0)out.illegal=1;out.rd_we=1;out.result=pc+(COMPRESSED?instruction_bytes:4);out.next_pc=(a+ii)&32'hfffffffe;end
   7'h63:begin
    case(f3)
     0:branch=(a==b);1:branch=(a!=b);4:branch=($signed(a)<$signed(b));5:branch=($signed(a)>=$signed(b));6:branch=(a<b);7:branch=(a>=b);default:out.illegal=1;
    endcase
    if(branch)out.next_pc=pc+ib;
   end
   7'h13,7'h33:begin
    out.rd_we=1;operand=(op==7'h13)?ii:b;
    if(bm[32])out.result=bm[31:0];
    else if(op==7'h33&&f7==1)begin
     if(MULTICYCLE_M) out.result=0; else begin
      case(f3)
       0:out.result=uu[31:0];1:out.result=ss[63:32];2:out.result=su[63:32];3:out.result=uu[63:32];
       4:begin if(b==0)out.result=32'hffffffff;else if(a==32'h80000000&&b==32'hffffffff)out.result=a;else out.result=$signed(a)/$signed(b);end
       5:out.result=(b==0)?32'hffffffff:a/b;
       6:begin if(b==0)out.result=a;else if(a==32'h80000000&&b==32'hffffffff)out.result=0;else out.result=$signed(a)%$signed(b);end
       7:out.result=(b==0)?a:a%b;
      endcase
     end
    end else begin
      case(f3)
       0:begin
        if(op==7'h33&&f7==7'h20)out.result=a-b;
        else begin out.result=a+operand;if(op==7'h33&&f7!=0)out.illegal=1;end
       end
       1:begin out.result=a<<operand[4:0];if(f7!=0)out.illegal=1;end
       2:begin out.result={31'd0,($signed(a)<$signed(operand))};if(op==7'h33&&f7!=0)out.illegal=1;end
       3:begin out.result={31'd0,(a<operand)};if(op==7'h33&&f7!=0)out.illegal=1;end
       4:begin out.result=a^operand;if(op==7'h33&&f7!=0)out.illegal=1;end
       5:begin
        if(f7==0)out.result=a>>operand[4:0];else if(f7==7'h20)out.result=$signed(a)>>>operand[4:0];else out.illegal=1;
       end
       6:begin out.result=a|operand;if(op==7'h33&&f7!=0)out.illegal=1;end
       7:begin out.result=a&operand;if(op==7'h33&&f7!=0)out.illegal=1;end
      endcase
    end
   end
   7'h03:begin
    out.mem=1;out.rd_we=1;out.addr=a+ii;out.load_kind=f3;
    case(f3)
     0,4:begin end
     1,5:if(out.addr[0])begin out.trap=1;out.cause=4;out.tval=out.addr;end
     2:if(out.addr[1:0]!=0)begin out.trap=1;out.cause=4;out.tval=out.addr;end
     default:out.illegal=1;
    endcase
   end
   7'h23:begin
    out.mem=1;out.we=1;out.addr=a+is_;out.wdata=b<<(out.addr[1:0]*8);
    case(f3)
     0:out.mask=4'b0001<<out.addr[1:0];
     1:begin out.mask=4'b0011<<out.addr[1:0];if(out.addr[0])begin out.trap=1;out.cause=6;out.tval=out.addr;end end
     2:begin out.mask=4'b1111;if(out.addr[1:0]!=0)begin out.trap=1;out.cause=6;out.tval=out.addr;end end
     default:out.illegal=1;
    endcase
   end
   7'h0f:begin
    // FENCE is a no-op: no cache, speculation or outstanding memory transactions.
    if(f3!=0 && !(COMPRESSED&&f3==1))out.illegal=1;
   end
   7'h73:begin
    if(insn==32'h00000073)begin out.trap=1;out.cause=11;out.tval=0;end
    else if(insn==32'h00100073)begin out.trap=1;out.cause=3;out.tval=pc;end
    else out.illegal=1;
   end
   default:out.illegal=1;
  endcase
  if(out.illegal)begin out.trap=1;out.cause=2;out.tval=insn;end
  else if(!out.trap&&(COMPRESSED?out.next_pc[0]:(out.next_pc[1:0]!=0)))begin out.trap=1;out.cause=0;out.tval=out.next_pc;end
  if(out.trap)begin out.mem=0;out.we=0;out.rd_we=0;end
 end
endmodule
