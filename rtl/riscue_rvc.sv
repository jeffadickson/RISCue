// RV32C integer decompressor. Raw encoding remains available to retirement.
module riscue_rvc(input logic [15:0] c,output logic [31:0] insn,output logic illegal);
 logic [4:0] rd,rs2,rp,rq;
 logic [31:0] imm;
 function automatic [31:0] i(input [6:0] op,input [2:0] f,input [4:0] d,a,input [31:0] v);
  i={v[11:0],a,f,d,op};
 endfunction
 function automatic [31:0] r(input [6:0] f7,input [2:0] f,input [4:0] d,a,b);
  r={f7,b,a,f,d,7'h33};
 endfunction
 function automatic [31:0] st(input [4:0] a,b,input [31:0] v);
  st={v[11:5],b,a,3'd2,v[4:0],7'h23};
 endfunction
 function automatic [31:0] j(input [4:0] d,input [31:0] v);
  j={v[20],v[10:1],v[11],v[19:12],d,7'h6f};
 endfunction
 function automatic [31:0] br(input [2:0] f,input [4:0] a,input [31:0] v);
  br={v[12],v[10:5],5'd0,a,f,v[4:1],v[11],7'h63};
 endfunction
 always_comb begin
  rd=c[11:7];rs2=c[6:2];rp={2'b01,c[9:7]};rq={2'b01,c[4:2]};
  imm=0;insn=32'h00000013;illegal=0;
  case(c[1:0])
   0:case(c[15:13])
    0:begin // ADDI4SPN
     imm={22'b0,c[10:7],c[12:11],c[5],c[6],2'b0};
     insn=i(7'h13,0,rq,2,imm);illegal=(imm==0);
    end
    2:begin imm={25'b0,c[5],c[12:10],c[6],2'b0};insn=i(7'h03,2,rq,rp,imm);end
    6:begin imm={25'b0,c[5],c[12:10],c[6],2'b0};insn=st(rp,rq,imm);end
    default:illegal=1; // floating-point and reserved encodings
   endcase
   1:case(c[15:13])
    0:begin imm={{26{c[12]}},c[12],c[6:2]};insn=i(7'h13,0,rd,rd,imm);end
    1,5:begin
     imm={{20{c[12]}},c[12],c[8],c[10:9],c[6],c[7],c[2],c[11],c[5:3],1'b0};
     insn=j(c[15:13]==1?5'd1:5'd0,imm);
    end
    2:begin imm={{26{c[12]}},c[12],c[6:2]};insn=i(7'h13,0,rd,0,imm);end
    3:begin
     if(rd==2)begin
      imm={{22{c[12]}},c[12],c[4:3],c[5],c[2],c[6],4'b0};
      insn=i(7'h13,0,2,2,imm);illegal=(imm==0);
     end else begin
      imm={{14{c[12]}},c[12],c[6:2],12'b0};insn={imm[31:12],rd,7'h37};
      illegal=(c[12:12]==0&&c[6:2]==0);
     end
    end
    4:case(c[11:10])
     0,1:begin
      insn=i(7'h13,5,rp,rp,{20'b0,(c[11:10]==1?7'h20:7'h00),c[6:2]});
      illegal=c[12];
     end
     2:begin imm={{26{c[12]}},c[12],c[6:2]};insn=i(7'h13,7,rp,rp,imm);end
     3:begin
      illegal=c[12];
      case(c[6:5])
       0:insn=r(7'h20,0,rp,rp,rq);
       1:insn=r(0,4,rp,rp,rq);
       2:insn=r(0,6,rp,rp,rq);
       3:insn=r(0,7,rp,rp,rq);
      endcase
     end
    endcase
    6,7:begin
     imm={{23{c[12]}},c[12],c[6:5],c[2],c[11:10],c[4:3],1'b0};
     insn=br(c[15:13]==6?3'd0:3'd1,rp,imm);
    end
   endcase
   2:case(c[15:13])
    0:begin insn=i(7'h13,1,rd,rd,{27'b0,c[6:2]});illegal=c[12];end
    2:begin imm={24'b0,c[3:2],c[12],c[6:4],2'b0};insn=i(7'h03,2,rd,2,imm);illegal=(rd==0);end
    4:begin
     if(!c[12])begin
      if(rs2==0)begin insn=i(7'h67,0,0,rd,0);illegal=(rd==0);end
      else insn=r(0,0,rd,0,rs2);
     end else if(rs2!=0)insn=r(0,0,rd,rd,rs2);
     else if(rd!=0)insn=i(7'h67,0,1,rd,0);
     else insn=32'h00100073;
    end
    6:begin imm={24'b0,c[8:7],c[12:9],2'b0};insn=st(2,rs2,imm);end
    default:illegal=1;
   endcase
   default:illegal=1;
  endcase
 end
endmodule
