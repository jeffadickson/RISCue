module formal_core_fault(input clk);
 import ft_pkg::*;
 parameter RF_TMR=0;
 reg started=0,injected=0;
 always @(posedge clk)started<=1;
 wire rst_n=started;
 (* anyseq *) reg ready,inject;
 (* anyseq *) reg [31:0] memory_data;
 (* anyconst *) reg [3:0] target;
 (* anyconst *) reg [8:0] bit_index;
 (* anyconst *) reg [4:0] reg_index;
 wire fire=started&&inject&&!injected;
 always @(posedge clk)if(fire)injected<=1;
 always @* begin
  assume(target>=5&&target<=7 || (RF_TMR ? (target>=2&&target<=4) : target==1));
  assume(bit_index<((target>=5)?$bits(control_t):(RF_TMR?32:39)));
  assume(reg_index!=0);
 end
 wire [511:0] mask=512'b1<<bit_index;
 wire req0,req1,fatal0,fatal1,halt0,halt1,trap0,trap1,ret0,ret1;
 wire [38:0] addr0,addr1,wd0,wd1,ct0,ct1;
 wire [31:0] pc0,pc1,rp0,rp1,ri0,ri1,rr0,rr1;
 wire [4:0] rd0,rd1;
 rv32im_ft_core #(.RF_TMR(RF_TMR),.BUS_TIMEOUT(8)) gold(
 .clk(clk),.rst_n(rst_n),.ready(ready),.rdata_code(ecc_encode(memory_data)),.bus_error(1'b0),.external_fault(1'b0),
 .fi_valid(1'b0),.fi_target(4'b0),.fi_index(32'b0),.fi_mask(512'b0),
 .req(req0),.addr_code(addr0),.wdata_code(wd0),.ctrl_code(ct0),.pc(pc0),.fatal(fatal0),.halted(halt0),.trap(trap0),
 .retire_valid(ret0),.retire_pc(rp0),.retire_insn(ri0),.retire_result(rr0),.retire_rd(rd0));
 rv32im_ft_core #(.RF_TMR(RF_TMR),.FI_ENABLE(1),.BUS_TIMEOUT(8)) dut(
 .clk(clk),.rst_n(rst_n),.ready(ready),.rdata_code(ecc_encode(memory_data)),.bus_error(1'b0),.external_fault(1'b0),
 .fi_valid(fire),.fi_target(target),.fi_index({27'b0,reg_index}),.fi_mask(mask),
 .req(req1),.addr_code(addr1),.wdata_code(wd1),.ctrl_code(ct1),.pc(pc1),.fatal(fatal1),.halted(halt1),.trap(trap1),
 .retire_valid(ret1),.retire_pc(rp1),.retire_insn(ri1),.retire_result(rr1),.retire_rd(rd1));
 always @(posedge clk)if(started)begin
  assert({req0,pc0,fatal0,halt0,trap0,ret0}=={req1,pc1,fatal1,halt1,trap1,ret1});
  if(req0)assert({addr0,wd0,ct0}=={addr1,wd1,ct1});
  if(ret0)assert({rp0,ri0,rr0,rd0}=={rp1,ri1,rr1,rd1});
  cover(injected&&ret1);
 end
endmodule
