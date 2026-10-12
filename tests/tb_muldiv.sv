`timescale 1ns/1ps
module tb_muldiv;
 logic clk=0,rst_n=0,start=0,cancel=0,fi_valid=0;
 logic [1:0] fi_replica=0;logic [511:0] fi_mask=0;
 logic [2:0] op;logic [31:0] lhs,rhs,result;
 wire ready,done,disagreement,fatal,fi_ack;
 always #5 clk=~clk;
 riscue_muldiv #(.FI_ENABLE(1)) dut(.*);
 function automatic [31:0] reference(input [2:0] f,input [31:0] a,b);
  reg signed [63:0] aa,bb,pp;
  begin
   aa={{32{a[31]}},a};bb={{32{b[31]}},b};
   case(f)
    0:reference=a*b;
    1:begin pp=aa*bb;reference=pp[63:32];end
    2:begin bb={32'b0,b};pp=aa*bb;reference=pp[63:32];end
    3:begin aa={32'b0,a};bb={32'b0,b};pp=aa*bb;reference=pp[63:32];end
    4:if(b==0)reference=32'hffffffff;else if(a==32'h80000000&&b==32'hffffffff)reference=a;else reference=$signed(a)/$signed(b);
    5:reference=b==0?32'hffffffff:a/b;
    6:if(b==0)reference=a;else if(a==32'h80000000&&b==32'hffffffff)reference=0;else reference=$signed(a)%$signed(b);
    7:reference=b==0?a:a%b;
   endcase
  end
 endfunction
 task automatic check(input [2:0] f,input [31:0] a,b);
  integer cycles;
  begin
   @(negedge clk);if(!ready)$fatal(1,"not ready");op=f;lhs=a;rhs=b;start=1;
   @(negedge clk);start=0;cycles=0;
   while(!done&&cycles<36)begin @(negedge clk);cycles=cycles+1;end
   if(!done||fatal||result!==reference(f,a,b))$fatal(1,"op=%d a=%h b=%h got=%h expected=%h",f,a,b,result,reference(f,a,b));
   if(cycles!=(f[2]?33:2))$fatal(1,"latency mismatch %d",cycles);
   @(negedge clk);if(done)$fatal(1,"completion repeated");
  end
 endtask
 integer f,k;
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  for(f=0;f<8;f=f+1)begin
   check(f,0,0);check(f,32'h80000000,32'hffffffff);check(f,32'hfffffff9,3);
   check(f,32'hffffffff,0);check(f,32'h7fffffff,32'hffffffff);
   for(k=0;k<256;k=k+1)check(f,$urandom,$urandom);
  end
  @(negedge clk);op=4;lhs=123;rhs=7;start=1;
  @(negedge clk);start=0;repeat(5)@(negedge clk);cancel=1;
  @(negedge clk);cancel=0;if(!ready||done)$fatal(1,"cancel failed");
  repeat(35)begin @(negedge clk);if(done)$fatal(1,"cancelled result escaped");end
  @(negedge clk);fi_valid=1;fi_mask=1;fi_replica=0;
  @(negedge clk);fi_valid=0;if(!disagreement)$fatal(1,"fault not observed");
  @(negedge clk);if(disagreement||fatal)$fatal(1,"repair failed");
  $display("PASS multicycle arithmetic");$finish;
 end
endmodule
