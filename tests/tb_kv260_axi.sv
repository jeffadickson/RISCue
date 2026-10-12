`timescale 1ns/1ps
module tb_kv260_axi #(parameter bit RF_TMR=0);
 logic aclk=0,aresetn=0;always #5 aclk=~aclk;
 logic [17:0] s_axi_awaddr=0,s_axi_araddr=0;
 logic [2:0] s_axi_awprot=0,s_axi_arprot=0;
 logic s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=0,s_axi_arvalid=0,s_axi_rready=0;
 logic [31:0] s_axi_wdata=0;logic [3:0] s_axi_wstrb=0;
 wire s_axi_awready,s_axi_wready,s_axi_bvalid,s_axi_arready,s_axi_rvalid;
 wire [1:0] s_axi_bresp,s_axi_rresp;wire [31:0] s_axi_rdata;
 logic [31:0] value;integer cycles;
 riscue_kv260_axi #(.WORDS(1024),.RF_TMR(RF_TMR)) dut(.*);
 task automatic write_reg(input [17:0] addr,input [31:0] data,input [3:0] mask,input [1:0] response);
  begin
   if(mask==8)begin // Exercise W arriving before AW as well as AW first.
    @(negedge aclk);s_axi_wdata=data;s_axi_wstrb=mask;s_axi_wvalid=1;
    @(posedge aclk);while(!s_axi_wready)@(posedge aclk);
    @(negedge aclk);s_axi_wvalid=0;repeat(2)@(negedge aclk);
    s_axi_awaddr=addr;s_axi_awvalid=1;
    @(posedge aclk);while(!s_axi_awready)@(posedge aclk);
    @(negedge aclk);s_axi_awvalid=0;
   end else begin
    @(negedge aclk);s_axi_awaddr=addr;s_axi_awvalid=1;
    @(posedge aclk);while(!s_axi_awready)@(posedge aclk);
    @(negedge aclk);s_axi_awvalid=0;
    repeat(2)@(negedge aclk);s_axi_wdata=data;s_axi_wstrb=mask;s_axi_wvalid=1;
    @(posedge aclk);while(!s_axi_wready)@(posedge aclk);
   end
   @(negedge aclk);s_axi_wvalid=0;cycles=0;
   while(!s_axi_bvalid&&cycles<1100)begin @(negedge aclk);cycles=cycles+1;end
   if(!s_axi_bvalid||s_axi_bresp!==response)$fatal(1,"write addr=%h response=%b expected=%b",addr,s_axi_bresp,response);
   repeat(3)begin @(negedge aclk);if(!s_axi_bvalid||s_axi_bresp!==response)$fatal(1,"B response lost under backpressure");end
   s_axi_bready=1;@(negedge aclk);s_axi_bready=0;
  end
 endtask
 task automatic read_reg(input [17:0] addr,input [1:0] response);
  begin
   @(negedge aclk);s_axi_araddr=addr;s_axi_arvalid=1;
   @(posedge aclk);while(!s_axi_arready)@(posedge aclk);
   @(negedge aclk);s_axi_arvalid=0;cycles=0;
   while(!s_axi_rvalid&&cycles<1100)begin @(negedge aclk);cycles=cycles+1;end
   if(!s_axi_rvalid||s_axi_rresp!==response)$fatal(1,"read addr=%h response=%b expected=%b",addr,s_axi_rresp,response);
   value=s_axi_rdata;
   repeat(3)begin @(negedge aclk);if(!s_axi_rvalid||s_axi_rdata!==value)$fatal(1,"R response lost under backpressure");end
   s_axi_rready=1;@(negedge aclk);s_axi_rready=0;
  end
 endtask
 initial begin
  repeat(3)@(negedge aclk);aresetn=1;repeat(3)@(negedge aclk);
  read_reg(0,0);if(value!=32'h52495343)$fatal(1,"identity");
  write_reg(8,4,15,0); // stop/reset endpoint; SRAM data retained
  write_reg(18'h10000,32'h00700093,15,0); // ADDI x1,x0,7
  write_reg(18'h10004,32'h30102023,15,0); // SW x1,0x300(x0)
  write_reg(18'h10008,32'h0000006f,15,0); // JAL x0,0
  write_reg(18'h10304,32'h12345678,15,0);
  write_reg(18'h10304,32'hab000000,8,0);
  read_reg(18'h10304,0);if(value!=32'hab345678)$fatal(1,"host byte store");
  write_reg(8,1,15,0);repeat(80)@(negedge aclk);
  read_reg(18'h30,0);if(value<3)$fatal(1,"core did not retire");
  read_reg(18'h10000,2);write_reg(18'h10000,0,15,2); // running loader is rejected
  write_reg(18'h40,8,15,0);write_reg(18'h44,1000,15,0);
  write_reg(18'h4c,1,15,0);write_reg(18'h50,1,15,0);write_reg(18'h54,2,15,0);
  write_reg(18'h80,1,15,0);write_reg(18'h48,3,15,0);
  repeat(30)@(negedge aclk);read_reg(18'h68,0);if(value!=32'h00010001)$fatal(1,"campaign acknowledgement");
  read_reg(18'h64,0);if(value[7:0]!=0)$fatal(1,"campaign failed");
  write_reg(8,0,15,0);read_reg(18'h10300,0);if(value!=7)$fatal(1,"core store not retained across stop/reset");
  read_reg(18'h3fc,2);
  $display("PASS KV260 AXI host loading, byte enables, running-access rejection, backpressure, telemetry and injection");$finish;
 end
 initial begin #1000000;$fatal(1,"AXI test timeout");end
endmodule
