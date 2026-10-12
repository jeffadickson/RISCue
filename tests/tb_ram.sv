module tb_ram;
 import ft_pkg::*;
 logic clk=0,rst_n=0,req=0;always #5 clk=~clk;
 logic [38:0] ac,wc,cc;wire ready,error,ce,fatal,de;wire [38:0] rc;
 ft_ecc_ram #(.WORDS(16)) dut(.clk(clk),.rst_n(rst_n),.req(req),.addr_code(ac),.wdata_code(wc),.ctrl_code(cc),.ready(ready),.error(error),.rdata_code(rc),.corrected_event(ce),.fatal(fatal),.disagreement_event(de),.fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0));
 ecc_result_t d;integer n;
 task transaction(input logic [38:0] a,w,c,input logic expected_error);begin
  @(negedge clk);ac=a;wc=w;cc=c;req=1;
  @(negedge clk);if(!ready||error!==expected_error)$fatal(1,"RAM response ready=%b err=%b",ready,error);
  req=0;@(negedge clk);
 end endtask
 initial begin
  ac=ecc_encode(0);wc=ecc_encode(0);cc=ecc_encode(0);repeat(2)@(negedge clk);rst_n=1;
  transaction(ecc_encode(4),ecc_encode(32'h12345678),ecc_encode(31),0);
  transaction(ecc_encode(4)^39'd1,ecc_encode(0),ecc_encode(0),0);d=ecc_decode(rc);if(d.data!=32'h12345678)$fatal(1,"address correction");
  transaction(ecc_encode(4)^39'd3,ecc_encode(32'hffffffff),ecc_encode(31),1);
  d=ecc_decode(dut.mem[1]);if(d.data!=32'h12345678)$fatal(1,"bad address wrote memory");
  transaction(ecc_encode(4),ecc_encode(32'hffffffff),ecc_encode(31)^39'd3,1);
  transaction(ecc_encode(4),ecc_encode(32'hffffffff)^39'd3,ecc_encode(31),1);
  d=ecc_decode(dut.mem[1]);if(d.data!=32'h12345678)$fatal(1,"bad control/data wrote memory");
  // Correct a stored upset as part of atomic byte RMW.
  @(negedge clk);dut.mem[1]=ecc_encode(32'h12345678)^39'd1;
  transaction(ecc_encode(4),ecc_encode(32'h0000aa00),ecc_encode(18),0);
  d=ecc_decode(dut.mem[1]);if(d.data!=32'h1234aa78||d.corrected)$fatal(1,"ECC byte RMW");
  @(negedge clk);dut.mem[1]=ecc_encode(32'h12345678)^39'd3;
  transaction(ecc_encode(4),ecc_encode(32'h0000aa00),ecc_encode(18),1);
  // This endpoint supports full-word overwrite without consuming corrupt old data.
  transaction(ecc_encode(4),ecc_encode(32'h87654321),ecc_encode(31),0);
  d=ecc_decode(dut.mem[1]);if(d.data!=32'h87654321)$fatal(1,"full overwrite");
  transaction(ecc_encode(64),ecc_encode(0),ecc_encode(0),1);
  $display("PASS RAM: corrected address, DED address/control/data containment, byte RMW, full overwrite, range check");$finish;
 end
 initial begin #10000;$fatal(1,"ram test timeout");end
endmodule
