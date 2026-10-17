`timescale 1ns/1ps
module tb_packet_demo;
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire fatal,trap,retire_valid;wire [31:0] pc,retire_pc,retire_insn,retire_result;wire [4:0] retire_rd;
 riscue_pipeline_soc #(.WORDS(1024)) dut(.clk(clk),.rst_n(rst_n),.external_irq(1'b0),
  .fatal(fatal),.trap(trap),.pc(pc),.retire_valid(retire_valid),.retire_pc(retire_pc),
  .retire_insn(retire_insn),.retire_result(retire_result),.retire_rd(retire_rd),
  .fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0));
 logic [31:0] image[0:1023];ecc_result_t decoded;
 integer cycle,retired,fd,finish_pc,packet_crc;bit completed=0;string trace_path,wave_path,image_path;
 initial begin
  if(!$value$plusargs("image=%s",image_path)||!$value$plusargs("trace=%s",trace_path)||
   !$value$plusargs("wave=%s",wave_path)||!$value$plusargs("finish=%d",finish_pc)||
   !$value$plusargs("packet_crc=%d",packet_crc))$fatal(1,"Missing demo arguments");
  $readmemh(image_path,image);fd=$fopen(trace_path,"w");if(fd==0)$fatal(1,"Trace open failed");
  $fwrite(fd,"cycle,pc,fvalid,fpc,dvalid,dpc,xvalid,xpc,mvalid,mpc,wvalid,wpc,retire,rpc,insn,rd,result,req,ready\n");
  $dumpfile(wave_path);$dumpvars(1,tb_packet_demo);
  repeat(3)@(negedge clk);
  for(integer i=0;i<1024;i++)dut.ram.mem[i]=ecc_encode(image[i]);
  rst_n=1;retired=0;
  for(cycle=0;cycle<30000&&!completed;cycle++)begin
   @(negedge clk);
   if(fatal||trap)$fatal(1,"Unexpected processor fault at PC %h",pc);
   $fwrite(fd,"%0d,%h,%0d,%h,%0d,%h,%0d,%h,%0d,%h,%0d,%h,%0d,%h,%h,%0d,%h,%0d,%0d\n",
    cycle,pc,dut.core.impl.s.f.valid,dut.core.impl.s.f.pc,dut.core.impl.s.d.valid,dut.core.impl.s.d.pc,
    dut.core.impl.s.x.valid,dut.core.impl.s.x.pc,dut.core.impl.s.m.valid,dut.core.impl.s.m.pc,
    dut.core.impl.s.w.valid,dut.core.impl.s.w.pc,retire_valid,retire_pc,retire_insn,retire_rd,retire_result,dut.req,dut.ready);
   if(retire_valid)begin
    retired++;
    if(retire_pc==finish_pc)begin
     decoded=ecc_decode(dut.ram.mem['hfc0/4]);if(decoded.data!==32'h50415353)$fatal(1,"No PASS signature");
     decoded=ecc_decode(dut.ram.mem['hfc4/4]);if(decoded.data!==32'h29b1)$fatal(1,"CRC check vector failed");
     decoded=ecc_decode(dut.ram.mem['hfc8/4]);if(decoded.data!==32'hffff)$fatal(1,"Empty CRC failed");
     decoded=ecc_decode(dut.ram.mem['hfcc/4]);if(decoded.data!==packet_crc)$fatal(1,"Binary packet CRC failed");
     $fclose(fd);$display("PASS packet CRC assembly: cycles=%0d retired=%0d check=29b1 empty=ffff packet=%04h",cycle+1,retired,packet_crc);completed=1;
    end
   end
  end
  if(!completed)$fatal(1,"CRC demo timed out");
  $finish;
 end
endmodule
