// Pure combinational RV32IM semantics. Two instances are compared before use.
module rv32_execute(input logic [31:0] insn,pc,a,b,output ft_pkg::exec_t out);
 import ft_pkg::*;
 logic [6:0] op,f7;logic [2:0] f3;logic [31:0] ii,is_,ib,iu,ij,operand,target;
 logic branch;logic signed [63:0] ss;logic signed [65:0] su;logic [63:0] uu;
 always @* begin
  op=insn[6:0];f3=insn[14:12];f7=insn[31:25];
  ii={{20{insn[31]}},insn[31:20]};is_={{20{insn[31]}},insn[31:25],insn[11:7]};
  ib={{19{insn[31]}},insn[31],insn[7],insn[30:25],insn[11:8],1'b0};
  iu={insn[31:12],12'd0};ij={{11{insn[31]}},insn[31],insn[19:12],insn[20],insn[30:21],1'b0};
  out='0;out.rd=insn[11:7];out.next_pc=pc+4;operand=0;target=0;branch=0;
  ss=$signed({{32{a[31]}},a})*$signed({{32{b[31]}},b});
  su=$signed({{34{a[31]}},a})*$signed({34'd0,b});uu={32'd0,a}*{32'd0,b};
  case(op)
   7'h37:begin out.rd_we=1;out.result=iu;end
   7'h17:begin out.rd_we=1;out.result=pc+iu;end
   7'h6f:begin out.rd_we=1;out.result=pc+4;out.next_pc=pc+ij;end
   7'h67:begin if(f3!=0)out.illegal=1;out.rd_we=1;out.result=pc+4;out.next_pc=(a+ii)&32'hfffffffe;end
   7'h63:begin
    case(f3)
     0:branch=(a==b);1:branch=(a!=b);4:branch=($signed(a)<$signed(b));5:branch=($signed(a)>=$signed(b));6:branch=(a<b);7:branch=(a>=b);default:out.illegal=1;
    endcase
    if(branch)out.next_pc=pc+ib;
   end
   7'h13,7'h33:begin
    out.rd_we=1;operand=(op==7'h13)?ii:b;
    if(op==7'h33&&f7==1)begin
      case(f3)
       0:out.result=uu[31:0];1:out.result=ss[63:32];2:out.result=su[63:32];3:out.result=uu[63:32];
       4:begin if(b==0)out.result=32'hffffffff;else if(a==32'h80000000&&b==32'hffffffff)out.result=a;else out.result=$signed(a)/$signed(b);end
       5:out.result=(b==0)?32'hffffffff:a/b;
       6:begin if(b==0)out.result=a;else if(a==32'h80000000&&b==32'hffffffff)out.result=0;else out.result=$signed(a)%$signed(b);end
       7:out.result=(b==0)?a:a%b;
      endcase
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
    if(f3!=0)out.illegal=1;
   end
   7'h73:begin
    if(insn==32'h00000073)begin out.trap=1;out.cause=11;out.tval=0;end
    else if(insn==32'h00100073)begin out.trap=1;out.cause=3;out.tval=pc;end
    else out.illegal=1;
   end
   default:out.illegal=1;
  endcase
  if(out.illegal)begin out.trap=1;out.cause=2;out.tval=insn;end
  else if(!out.trap&&out.next_pc[1:0]!=0)begin out.trap=1;out.cause=0;out.tval=out.next_pc;end
  if(out.trap)begin out.mem=0;out.we=0;out.rd_we=0;end
 end
endmodule
