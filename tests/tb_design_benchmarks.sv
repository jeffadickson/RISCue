`timescale 1ns/1ps
module tb_design_benchmarks;
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire req,fatal,retire_valid;wire [38:0] ac,wc,cc,rc;wire [31:0] rpc,ri,result;wire [4:0] rd;wire [31:0] ma,mr,mw;wire [3:0] rmask,wmask;
 riscue_pipeline_core #(.RF_TMR(0),.FI_ENABLE(0)) core(
  .clk(clk),.rst_n(rst_n),.req(req),.addr_code(ac),.wdata_code(wc),.ctrl_code(cc),
  .ready(ack),.bus_error(error),.external_fault(1'b0),.rdata_code(rc),.fatal(fatal),
  .retire_valid(retire_valid),.retire_pc(rpc),.retire_insn(ri),.retire_rd(rd),.retire_result(result),.rvfi_mem_addr(ma),.rvfi_mem_rdata(mr),.rvfi_mem_wdata(mw),.rvfi_mem_rmask(rmask),.rvfi_mem_wmask(wmask),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0),
  .external_irq(1'b0),.debug_haltreq(1'b0),.debug_resumereq(1'b0),.debug_reg_valid(1'b0),
  .debug_reg_write(1'b0),.debug_regno(16'b0),.debug_wdata(32'b0),.halt_request(1'b0),.boot_pc(32'b0));
 logic [31:0] mem[0:1023],response=0,address,data,control;
 logic ack=0,error=0,waiting=0;integer delay_left=0,wait_states=0;
 logic [38:0] held_ac,held_wc,held_cc;
 ecc_result_t ad,wd,cd;
`ifdef RISCUE_PLAIN_MEMORY
 assign rc={7'b0,response};
 always @* begin address=ac[31:0];data=wc[31:0];control=cc[31:0];end
`else
 assign rc=ecc_encode(response);
 always @* begin ad=ecc_decode(ac);wd=ecc_decode(wc);cd=ecc_decode(cc);address=ad.data;data=wd.data;control=cd.data;end
`endif
 always @(posedge clk)begin
  if(!rst_n)begin ack<=0;error<=0;response<=0;waiting=0;delay_left=0;end
  else begin
   ack<=0;error<=0;
   if(waiting&&(!req||ac!==held_ac||wc!==held_wc||cc!==held_cc))$fatal(1,"request changed while memory stalled");
   if(req&&!ack)begin
    if(!waiting)begin waiting=1;delay_left=wait_states;held_ac=ac;held_wc=wc;held_cc=cc;end
    if(delay_left==0)begin
     ack<=1;waiting=0;
     if(address[1:0]!=0||address>=4096)begin error<=1;response<=0;end
     else begin
      response<=mem[address[31:2]];
      if(control[4])for(integer b=0;b<4;b=b+1)if(control[b])mem[address[31:2]][b*8+:8]<=data[b*8+:8];
     end
    end else delay_left=delay_left-1;
   end
  end
 end
 integer branches=0,taken=0,jals=0,jalrs=0;
 // Shadow predictors observe retirement only: direction estimates, no RTL changes.
 logic [1:0] table16[0:15],table64[0:63],table256[0:255];
 integer hits16=0,hits64=0,hits256=0,hits_btfnt=0;
 logic outcome;integer ix16,ix64,ix256;
 initial begin
  for(integer i=0;i<16;i=i+1)table16[i]=1;
  for(integer i=0;i<64;i=i+1)table64[i]=1;
  for(integer i=0;i<256;i=i+1)table256[i]=1;
 end
 integer cycles=0,retired=0;logic [31:0] finish_pc,expected;string image;
 logic [63:0] trace_hash=64'hcbf29ce484222325;
 initial begin
  if(!$value$plusargs("image=%s",image)||!$value$plusargs("finish=%h",finish_pc)||
     !$value$plusargs("expected=%h",expected))$fatal(1,"missing benchmark arguments");
  if($value$plusargs("wait=%d",wait_states))begin end
  $readmemh(image,mem);repeat(3)@(negedge clk);rst_n=1;
 end
 always @(posedge clk)if(rst_n)begin
  cycles=cycles+1;
  if(fatal)$fatal(1,"hardware fatal at cycle %d",cycles);
  if(`RISCUE_MULTICYCLE&&((core.impl.s.f.valid?1:0)+(core.impl.s.d.valid?1:0)+
      (core.impl.s.x.valid?1:0)+(core.impl.s.m.valid?1:0)+(core.impl.s.w.valid?1:0)>1))
   $fatal(1,"non-pipelined core contains overlapping instructions");
  if(retire_valid)begin
   retired=retired+1;
   // Expanded retired instruction includes compressed branch/jump forms.
   if(core.impl.s.retired.insn[6:0]==7'h63)begin
    branches=branches+1;
    outcome=core.impl.s.retired.e.next_pc!=rpc+core.impl.s.retired.bytes;
    ix16=(rpc>>1)&15;ix64=(rpc>>1)&63;ix256=(rpc>>1)&255;
    if(table16[ix16][1]==outcome)hits16=hits16+1;
    if(table64[ix64][1]==outcome)hits64=hits64+1;
    if(table256[ix256][1]==outcome)hits256=hits256+1;
    if(core.impl.s.retired.insn[31]==outcome)hits_btfnt=hits_btfnt+1;
    if(outcome)begin
     if(table16[ix16]!=3)table16[ix16]=table16[ix16]+1'b1;
     if(table64[ix64]!=3)table64[ix64]=table64[ix64]+1'b1;
     if(table256[ix256]!=3)table256[ix256]=table256[ix256]+1'b1;
    end else begin
     if(table16[ix16]!=0)table16[ix16]=table16[ix16]-1'b1;
     if(table64[ix64]!=0)table64[ix64]=table64[ix64]-1'b1;
     if(table256[ix256]!=0)table256[ix256]=table256[ix256]-1'b1;
    end
    if(core.impl.s.retired.e.next_pc!=rpc+core.impl.s.retired.bytes)taken=taken+1;
   end
   if(core.impl.s.retired.insn[6:0]==7'h6f)jals=jals+1;
   if(core.impl.s.retired.insn[6:0]==7'h67)jalrs=jalrs+1;
   trace_hash=(trace_hash^{rpc,ri})*64'h100000001b3;
   trace_hash=(trace_hash^{27'b0,rd,(rd==0?32'b0:result)})*64'h100000001b3;
   if(rmask!=0||wmask!=0)begin
    trace_hash=(trace_hash^{ma,24'b0,rmask,wmask})*64'h100000001b3;
    trace_hash=(trace_hash^{(rmask!=0?mr:32'b0),(wmask!=0?mw:32'b0)})*64'h100000001b3;
   end
   if(rpc==finish_pc)begin
    if(mem[1008]!==expected||mem[1009]!==32'h434f5245)$fatal(1,"benchmark checksum %h expected %h",mem[1008],expected);
    $display("SHADOW_PREDICT correct16=%0d correct64=%0d correct256=%0d correct_btfnt=%0d",hits16,hits64,hits256,hits_btfnt);
    $display("BRANCH_STATS conditional=%0d taken=%0d not_taken=%0d direct_jumps=%0d indirect_jumps=%0d",branches,taken,branches-taken,jals,jalrs);
    $display("BENCH_PASS cycles=%0d instructions=%0d checksum=%08h trace=%016h",cycles,retired,mem[1008],trace_hash);$finish;
   end
  end
  if(cycles>300000)$fatal(1,"benchmark instruction timeout");
 end
endmodule
