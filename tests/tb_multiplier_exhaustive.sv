`timescale 1ns/1ps
module tb_multiplier_exhaustive;
 logic clk=0,rst_n=0,start=0;logic [2:0] op;logic [31:0] lhs,rhs,expected;
 wire [31:0] result0,result1;wire ready0,ready1,done0,done1,fatal0,fatal1,dis0,dis1;
 always #5 clk=~clk;
 riscue_muldiv lane0(.clk(clk),.rst_n(rst_n),.start(start),.cancel(1'b0),.op(op),.lhs(lhs),.rhs(rhs),.result(result0),.ready(ready0),.done(done0),.fatal(fatal0),.disagreement(dis0),.fi_valid(1'b0),.fi_replica(2'd0),.fi_mask(512'd0),.fi_ack());
 riscue_muldiv lane1(.clk(clk),.rst_n(rst_n),.start(start),.cancel(1'b0),.op(op),.lhs(lhs),.rhs(rhs),.result(result1),.ready(ready1),.done(done1),.fatal(fatal1),.disagreement(dis1),.fi_valid(1'b0),.fi_replica(2'd0),.fi_mask(512'd0),.fi_ack());
 integer fd,n,count,cycles;integer counts[0:3];
 initial begin
  count=0;for(n=0;n<4;n=n+1)counts[n]=0;
  fd=$fopen("build/multiplier_vectors.txt","r");if(!fd)$fatal(1,"Missing vectors");
  repeat(3)@(negedge clk);rst_n=1;
  while(!$feof(fd))begin
   n=$fscanf(fd,"%h %h %h %h\n",op,lhs,rhs,expected);
   if(n==4)begin
    if(!ready0||!ready1)$fatal(1,"Not ready");start=1;
    @(negedge clk);start=0;cycles=0;
    while(!done0&&cycles<4)begin @(negedge clk);cycles=cycles+1;end
    if(!done0||!done1||cycles!=2||result0!==expected||result1!==expected||fatal0||fatal1||dis0||dis1)
     $fatal(1,"Multiply mismatch op=%0d a=%h b=%h got=%h/%h expected=%h cycles=%0d",op,lhs,rhs,result0,result1,expected,cycles);
    counts[op]=counts[op]+1;count=count+1;
    @(negedge clk);if(done0||done1)$fatal(1,"Duplicate completion");
   end
  end
  $display("PASS exhaustive multiplier total=%0d MUL=%0d MULH=%0d MULHSU=%0d MULHU=%0d",count,counts[0],counts[1],counts[2],counts[3]);$finish;
 end
endmodule
