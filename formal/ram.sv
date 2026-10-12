module formal_ram(input clk);
 import ft_pkg::*;
 parameter DOUBLE=0;
 parameter integer BIT_A=-1;
 reg [3:0] cycle=0;
 always @(posedge clk)if(cycle<10)cycle<=cycle+1;
 (* anyconst *) reg [31:0] data;
 (* anyconst *) reg [5:0] bit_a,bit_b;
 (* anyconst *) reg location;
 always @*begin assume(bit_a<39);assume(bit_b<39);assume(bit_a!=bit_b);end
 wire [38:0] mask=(39'b1<<((BIT_A<0)?bit_a:BIT_A))^(DOUBLE?(39'b1<<bit_b):39'b0);
 wire ready,error,fatal,corrected,ack;
 wire [38:0] result;
 wire req=(cycle==1||cycle==4||cycle==7);
 wire [31:0] address={29'b0,location,2'b0};
 wire [31:0] ctrl=cycle==1?32'h1f:0;
 ft_ecc_ram #(.WORDS(2),.FI_ENABLE(1)) dut(
 .clk(clk),.rst_n(cycle!=0),.req(req),.addr_code(ecc_encode(address)),.wdata_code(ecc_encode(data)),.ctrl_code(ecc_encode(ctrl)),
 .ready(ready),.error(error),.rdata_code(result),.fatal(fatal),.corrected_event(corrected),
 .fi_valid(cycle==3),.fi_target(4'd8),.fi_index({31'b0,location}),.fi_mask({473'b0,mask}),.fi_ack(ack));
 ecc_result_t decoded;
 always @*decoded=ecc_decode(result);
 always @(posedge clk)begin
  if(cycle==2)assert(ready&&!error&&!fatal);
  if(cycle==3)assert(ack);
  if(cycle==5)begin
   assert(ready&&!fatal);
   if(DOUBLE)begin assert(error);end
   else begin assert(!error&&decoded.data==data&&!decoded.corrected&&!decoded.uncorrectable);end
  end
  if(cycle==8&&!DOUBLE)assert(ready&&!error&&decoded.data==data);

 end
generate if(DOUBLE)begin
 always @(posedge clk)cover(cycle==5&&ready&&error);
end else begin
 always @(posedge clk)cover(cycle==8&&ready&&!error);
end endgenerate
endmodule
