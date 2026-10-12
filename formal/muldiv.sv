module formal_muldiv #(parameter integer FUNCT3=0)(input clk);
 (* anyconst *) logic [31:0] a,b;
 logic [5:0] cycle=0;
 wire rst_n=cycle!=0,start=cycle==1;
 wire ready,done,disagreement,fatal,fi_ack;wire [31:0] result;
 logic [31:0] expected;logic signed [63:0] sa,sb,product;
 always_comb begin
  sa={{32{a[31]}},a};sb={{32{b[31]}},b};product=0;expected=0;
  case(FUNCT3)
   0:expected=a*b;
   1:begin product=sa*sb;expected=product[63:32];end
   2:begin sb={32'b0,b};product=sa*sb;expected=product[63:32];end
   3:begin sa={32'b0,a};sb={32'b0,b};product=sa*sb;expected=product[63:32];end
   4:if(b==0)expected=32'hffffffff;else if(a==32'h80000000&&b==32'hffffffff)expected=a;else expected=$signed(a)/$signed(b);
   5:expected=b==0?32'hffffffff:a/b;
   6:if(b==0)expected=a;else if(a==32'h80000000&&b==32'hffffffff)expected=0;else expected=$signed(a)%$signed(b);
   7:expected=b==0?a:a%b;
  endcase
 end
 riscue_muldiv dut(.clk(clk),.rst_n(rst_n),.start(start),.cancel(1'b0),.op(3'(FUNCT3)),.lhs(a),.rhs(b),
  .ready(ready),.done(done),.disagreement(disagreement),.fatal(fatal),.result(result),
  .fi_valid(1'b0),.fi_replica(2'b0),.fi_mask(512'b0),.fi_ack(fi_ack));
 always @(posedge clk)begin
  if(cycle<40)cycle<=cycle+1;
  if(rst_n)begin assert(!fatal);assert(!disagreement);end
  if(done)begin assert(result==expected);cover(done);end
 end
endmodule
