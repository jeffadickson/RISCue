`timescale 1ns/1ps
module tb_pipeline_jump #(parameter bit RF_TMR=0,EARLY_JUMP=1);
 import ft_pkg::*;
 logic clk=0,rst_n=0;always #5 clk=~clk;
 wire fatal,retire_valid,trap;wire [31:0] pc,trap_cause,retire_pc,retire_result;wire [4:0] retire_rd;
 integer cycles=0,retired=0,traps=0;logic [31:0] image[0:1023];
 integer expected_pc[0:29];
 riscue_pipeline_soc #(.WORDS(1024),.RF_TMR(RF_TMR),.EARLY_JUMP(EARLY_JUMP)) dut(
  .clk(clk),.rst_n(rst_n),.external_irq(1'b0),.fatal(fatal),.trap(trap),.pc(pc),.trap_cause(trap_cause),
  .retire_valid(retire_valid),.retire_pc(retire_pc),.retire_rd(retire_rd),.retire_result(retire_result),
  .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0));
 function automatic [31:0] csr(input [11:0] addr,input [4:0] rd,rs,input [2:0] f);csr={addr,rs,f,rd,7'h73};endfunction
 function automatic [31:0] jal(input [4:0] rd,input [31:0] off);jal={off[20],off[10:1],off[11],off[19:12],rd,7'h6f};endfunction
 task automatic check(input [4:0] rd,input [31:0] value);
  if(retire_rd!==rd||retire_result!==value)$fatal(1,"pc=%h rd=%d result=%h expected rd=%d value=%h",retire_pc,retire_rd,retire_result,rd,value);
 endtask
 initial begin
  for(integer k=0;k<1024;k=k+1)image[k]=0;
  image[0]=32'h10000293;image[1]=csr(12'h305,0,5,1);
  image[2]=jal(1,12);image[3]=32'h34002023;image[4]=32'hffffffff;
  image[5]=32'h90022021;image[6]=32'hffffffff;
  image[7]=32'h9002a021;image[8]=32'hffffffff;
  image[9]=32'h00300113;image[10]=32'hfff10113;
  image[11]=32'h00010463;image[12]=jal(0,-8);
  image[13]=32'h00000073;image[14]=jal(3,8);image[15]=32'hffffffff;
  image[16]=32'h00118213;image[17]=32'hffffffff;image[18]=jal(6,8);image[19]=32'hffffffff;image[20]=32'h00130393;
  image[64]=csr(12'h342,20,0,2);image[65]=csr(12'h341,21,0,2);
  image[66]=32'h004a8a93;image[67]=csr(12'h341,0,21,1);image[68]=32'h30200073;
  expected_pc[0]=0;expected_pc[1]=4;expected_pc[2]=8;expected_pc[3]=20;expected_pc[4]=28;expected_pc[5]=36;
  expected_pc[6]=40;expected_pc[7]=44;expected_pc[8]=48;expected_pc[9]=40;expected_pc[10]=44;expected_pc[11]=48;
  expected_pc[12]=40;expected_pc[13]=44;expected_pc[14]=52;
  for(integer k=0;k<5;k=k+1)begin expected_pc[15+k]=256+4*k;expected_pc[23+k]=256+4*k;end
  expected_pc[20]=56;expected_pc[21]=64;expected_pc[22]=68;expected_pc[28]=72;expected_pc[29]=80;
  repeat(3)@(negedge clk);
  for(integer k=0;k<1024;k=k+1)begin
`ifdef RISCUE_PLAIN_MEMORY
 dut.plain.mem[k]=image[k];
`else
 dut.ram.mem[k]=ecc_encode(image[k]);
`endif
 end;rst_n=1;
  while(cycles<2000)begin
   @(negedge clk);cycles=cycles+1;
   if(fatal)$fatal(1,"hardware fatal");
   if(trap)begin
    if(trap_cause!=(traps==0?11:2))$fatal(1,"wrong-path instruction trapped: %d",trap_cause);
    traps=traps+1;
   end
   if(retire_valid)begin
    if(retired>=30||retire_pc!==expected_pc[retired])$fatal(1,"wrong path/order at retire %d pc=%h expected=%h",retired,retire_pc,expected_pc[retired]);
    case(retire_pc)
     8:check(1,12);20:check(1,22);56:check(3,60);64:check(4,61);72:check(6,76);80:check(7,77);
    endcase
    retired=retired+1;
    if(retire_pc==80)begin
     if(traps!=2||retired!=30)$fatal(1,"trap/retirement count");
     $display("PASS direct jump RF_TMR=%d EARLY_JUMP=%d retirements=%d clocks=%d",RF_TMR,EARLY_JUMP,retired,cycles);$finish;
    end
   end
  end
  $fatal(1,"jump timeout pc=%h retired=%d",pc,retired);
 end
endmodule
