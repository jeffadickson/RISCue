// Arbitrary operands and immediate indices; independent polynomial convolution.
module formal_bitmanip #(parameter integer OP=0);
 import ft_pkg::*;
 (* anyconst *) logic [31:0] a,b;
 (* anyconst *) logic [4:0] immediate;
 logic [31:0] insn,expected;logic [4:0] sh;logic [63:0] doubled,polynomial;
 integer j,k;exec_t out;
 riscue_execute #(.COMPRESSED(1),.MULTICYCLE_M(1)) dut(.instruction_bytes(3'd4),.insn(insn),.pc(32'd0),.a(a),.b(b),.out(out));
 always @* begin
  insn=0;expected=0;sh=b[4:0];doubled={a,a};polynomial=0;
  for(j=0;j<32;j=j+1)for(k=0;k<32;k=k+1)
   polynomial[j+k]=polynomial[j+k]^(a[j]&b[k]);
  case(OP)
   0:begin insn=32'h4020f1b3;expected=a & ~b;end
   1:begin insn=32'h4020e1b3;expected=a | ~b;end
   2:begin insn=32'h4020c1b3;expected=~(a ^ b);end
   3:begin insn=32'h0a20c1b3;expected=($signed(a)<$signed(b))?a:b;end
   4:begin insn=32'h0a20d1b3;expected=(a<b)?a:b;end
   5:begin insn=32'h0a20e1b3;expected=($signed(a)>$signed(b))?a:b;end
   6:begin insn=32'h0a20f1b3;expected=(a>b)?a:b;end
   7:begin insn=32'h0800c1b3;expected={16'd0,a[15:0]};end
   8:begin insn=32'h602091b3;expected=doubled >> (32-sh);end
   9:begin insn=32'h6020d1b3;expected=doubled >> sh;end
   10:begin insn=32'h0a2091b3;expected=polynomial[31:0];end
   11:begin insn=32'h0a20a1b3;expected=polynomial[62:31];end
   12:begin insn=32'h0a20b1b3;expected=polynomial[63:32];end
   13:begin insn=32'h482091b3;expected=a & ~(32'd1 << sh);end
   14:begin insn=32'h4820d1b3;expected=(a >> sh) & 1;end
   15:begin insn=32'h682091b3;expected=a ^ (32'd1 << sh);end
   16:begin insn=32'h282091b3;expected=a | (32'd1 << sh);end
   17:begin insn=32'h60009193;expected=0;for(j=0;j<32;j=j+1)if((a >> j)==0)expected=expected+1;end
   18:begin insn=32'h60109193;expected=32;for(j=0;j<32;j=j+1)if(a[j]&&expected==32)expected=j;end
   19:begin insn=32'h60209193;for(j=0;j<32;j=j+1)if(a[j])expected=expected+1;end
   20:begin insn=32'h60409193;expected={{24{a[7]}},a[7:0]};end
   21:begin insn=32'h60509193;expected={{16{a[15]}},a[15:0]};end
   22:begin insn=32'h2870d193;for(j=0;j<4;j=j+1)if(a[j*8+:8]!=0)expected[j*8+:8]=255;end
   23:begin insn=32'h6980d193;expected={a[7:0],a[15:8],a[23:16],a[31:24]};end
   24:begin insn=32'h6000d193;insn[24:20]=immediate;sh=immediate;expected=doubled >> sh;end
   25:begin insn=32'h48009193;insn[24:20]=immediate;sh=immediate;expected=a & ~(32'd1 << sh);end
   26:begin insn=32'h4800d193;insn[24:20]=immediate;sh=immediate;expected=(a >> sh) & 1;end
   27:begin insn=32'h68009193;insn[24:20]=immediate;sh=immediate;expected=a ^ (32'd1 << sh);end
   28:begin insn=32'h28009193;insn[24:20]=immediate;sh=immediate;expected=a | (32'd1 << sh);end
  endcase
  assert(!out.illegal&&!out.trap&&out.rd_we&&out.rd==3);
  assert(out.result==expected&&out.next_pc==4&&!out.mem&&!out.we);
 end
endmodule
