`timescale 1ns/1ps
// Common RV32IM trace only: deliberately excludes compressed/CSR/interrupt behavior.
module tb_architecture_compare;
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire req,ready,error,fatal,retire_valid;
 wire [38:0] ac,wc,cc,rc;
 wire [31:0] rpc,ri,result;wire [4:0] rd;
`ifdef COMPARE_LEGACY
 rv32im_ft_core #(.RF_TMR(0),.FI_ENABLE(0)) core(
`else
 riscue_pipeline_core #(.RF_TMR(0),.FI_ENABLE(0)) core(
`endif
  .clk(clk),.rst_n(rst_n),.req(req),.addr_code(ac),.wdata_code(wc),.ctrl_code(cc),
  .ready(ready),.bus_error(error),.external_fault(1'b0),.rdata_code(rc),.fatal(fatal),
  .retire_valid(retire_valid),.retire_pc(rpc),.retire_insn(ri),.retire_rd(rd),.retire_result(result),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0)
`ifndef COMPARE_LEGACY
  ,.external_irq(1'b0),.debug_haltreq(1'b0),.debug_resumereq(1'b0),.debug_reg_valid(1'b0),
  .debug_reg_write(1'b0),.debug_regno(16'b0),.debug_wdata(32'b0),.halt_request(1'b0),.boot_pc(32'b0)
`endif
 );
 // Identical one-port response latency and capacity; plain merely bypasses encoding.
 logic ack=0,err=0;logic [31:0] response=0,mem[0:511];
 ecc_result_t ad,wd,cd;logic [31:0] address,data,control;
 assign ready=ack;assign error=err;
`ifdef COMPARE_PLAIN
 assign rc={7'b0,response};
 always @* begin address=ac[31:0];data=wc[31:0];control=cc[31:0];end
`else
 assign rc=ecc_encode(response);
 always @* begin ad=ecc_decode(ac);wd=ecc_decode(wc);cd=ecc_decode(cc);address=ad.data;data=wd.data;control=cd.data;end
`endif
 always @(posedge clk)begin
  if(!rst_n)begin ack<=0;err<=0;response<=0;end
  else begin
   ack<=0;err<=0;
   if(req&&!ack)begin
    ack<=1;
    if(address[1:0]!=0||address>=2048)begin err<=1;response<=0;end
    else begin
     response<=mem[address[31:2]];
     if(control[4])for(integer b=0;b<4;b=b+1)if(control[b])mem[address[31:2]][b*8+:8]<=data[b*8+:8];
    end
   end
  end
 end
 integer fd,n=0,cycles=0,expected,got;reg [31:0] epc,ei,erd,ev;
 initial begin
  if(!$value$plusargs("expected=%d",expected))$fatal(1,"expected count missing");
  $readmemh("build/program.hex",mem);
  fd=$fopen("build/program.trace","r");if(!fd)$fatal(1,"golden trace missing");
  repeat(3)@(negedge clk);rst_n=1;
 end
 always @(posedge clk)if(rst_n)begin
  cycles=cycles+1;
  if(fatal)$fatal(1,"unexpected hardware fatal at %d",cycles);
  if(retire_valid)begin
   got=$fscanf(fd,"%h %h %h %h\n",epc,ei,erd,ev);
   // x0 result is architecturally discarded; old legacy retire bus leaves it unspecified.
   if(got!=4||rpc!==epc||ri!==ei||rd!==erd[4:0]||(rd!=0&&result!==ev))
    $fatal(1,"trace mismatch n=%d pc=%h/%h insn=%h/%h rd=%d/%d result=%h/%h",n,rpc,epc,ri,ei,rd,erd,result,ev);
   n=n+1;
   if(n==expected)begin $display("COMPARE_PASS retired=%0d cycles=%0d",n,cycles);$finish;end
  end
  if(cycles>20000)$fatal(1,"comparison timeout n=%d",n);
 end
endmodule
