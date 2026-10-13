`timescale 1ns/1ps
module tb_axi_core #(parameter bit RF_TMR=0,STORE_ERROR=0);
 logic aclk=0,aresetn=0,external_irq=0;
 wire [31:0] m_axi_awaddr,m_axi_wdata,m_axi_araddr;wire [2:0] m_axi_awprot,m_axi_arprot;
 wire [3:0] m_axi_wstrb;wire m_axi_awvalid,m_axi_wvalid,m_axi_bready,m_axi_arvalid,m_axi_rready;
 logic m_axi_awready,m_axi_wready,m_axi_arready;
 logic [1:0] m_axi_bresp=0,m_axi_rresp=0;logic m_axi_bvalid=0,m_axi_rvalid=0;logic [31:0] m_axi_rdata=0;
 wire halted,fatal,trap,retire_valid,corrected_event,disagreement_event,bridge_fatal,fi_ack;
 wire [31:0] pc,trap_cause,trap_value,retire_pc,retire_insn,retire_result,core_event_address;
 wire [4:0] retire_rd;wire [7:0] core_event_flags;
 logic fi_valid=0;logic [3:0] fi_target=0;logic [31:0] fi_index=0;logic [511:0] fi_mask=0;
 riscue_axi_core #(.RF_TMR(RF_TMR)) dut(.*);
 always #5 aclk=~aclk;
 logic [31:0] mem[0:255],awaddr,wd,read_addr;logic [3:0] mask;
 logic awheld=0,wheld=0;integer cycle=0,rd_delay=0,wr_delay=0,j,retired=0,reads=0,writes=0;
 // Deliberately asymmetric AW/W acceptance and delayed read/write responses.
 always_comb begin
  m_axi_awready=aresetn&&!awheld&&!m_axi_bvalid&&wr_delay==0&&(cycle%5==0);
  m_axi_wready=aresetn&&!wheld&&!m_axi_bvalid&&wr_delay==0&&(cycle%3==1);
  m_axi_arready=aresetn&&!m_axi_rvalid&&rd_delay==0&&(cycle%4==2);
 end
 always @(posedge aclk)begin
  if(!aresetn)begin cycle<=0;awheld<=0;wheld<=0;rd_delay<=0;wr_delay<=0;m_axi_rvalid<=0;m_axi_bvalid<=0;end
  else begin
   cycle<=cycle+1;
   if(m_axi_arvalid&&m_axi_arready)begin read_addr<=m_axi_araddr;rd_delay<=3;reads<=reads+1;end
   else if(rd_delay>0)begin
    rd_delay<=rd_delay-1;
    if(rd_delay==1)begin m_axi_rvalid<=1;m_axi_rresp<=read_addr>=1024?2'b10:0;m_axi_rdata<=read_addr>=1024?0:mem[read_addr>>2];end
   end
   if(m_axi_rvalid&&m_axi_rready)m_axi_rvalid<=0;
   if(m_axi_awvalid&&m_axi_awready)begin awheld<=1;awaddr<=m_axi_awaddr;end
   if(m_axi_wvalid&&m_axi_wready)begin wheld<=1;wd<=m_axi_wdata;mask<=m_axi_wstrb;end
   if(awheld&&wheld&&!m_axi_bvalid&&wr_delay==0)begin
    awheld<=0;wheld<=0;wr_delay<=3;writes<=writes+1;
    for(j=0;j<4;j=j+1)if(mask[j]&&awaddr<1024)mem[awaddr>>2][j*8+:8]<=wd[j*8+:8];
   end
   if(wr_delay>0)begin wr_delay<=wr_delay-1;if(wr_delay==1)begin m_axi_bvalid<=1;m_axi_bresp<=awaddr>=1024?2'b11:0;end end
   if(m_axi_bvalid&&m_axi_bready)m_axi_bvalid<=0;
   if(fatal)$fatal(1,"unexpected hardware fatal");
   if(retire_valid)begin
    retired<=retired+1;
    case(retire_pc)
     8:if(retire_result!=21)$fatal(1,"MUL mismatch");
     16:if(retire_result!=21)$fatal(1,"load mismatch");
     20:if(retire_result!=22)$fatal(1,"forwarding mismatch");
     28:if(retire_result!=3)$fatal(1,"byte load mismatch");
    endcase
   end
   if(trap)begin
    if(trap_cause!=(STORE_ERROR?7:5)||trap_value!=1024||mem[194]!=0||mem[193]!=22||mem[192]!=32'h315)$fatal(1,"AXI fault/trap or memory mismatch cause=%h tval=%h",trap_cause,trap_value);
    $display("PASS AXI processor RF_TMR=%0d STORE_ERROR=%0d cycles=%0d retirements=%0d reads=%0d writes=%0d access-fault precise",RF_TMR,STORE_ERROR,cycle,retired,reads,writes);$finish;
   end
   if(cycle>2000)$fatal(1,"timeout");
  end
 end
 initial begin
  for(j=0;j<256;j=j+1)mem[j]=0;
  mem[0]=32'h00700093;mem[1]=32'h00300113;mem[2]=32'h022081b3;
  mem[3]=32'h30302023;mem[4]=32'h30002203;mem[5]=32'h00120293;
  mem[6]=32'h302000a3;mem[7]=32'h30104303;mem[8]=32'h30502223;
  mem[9]=STORE_ERROR?32'h40502023:32'h40002383;mem[10]=32'h30502423;mem[11]=32'h0000006f;
  repeat(3)@(negedge aclk);aresetn=1;
 end
 // Protocol stability across backpressure, independently of the slave model.
 logic aw_stall=0,w_stall=0,ar_stall=0;logic [31:0] prev_aw,prev_w,prev_ar;logic [3:0] prev_mask;
 always @(posedge aclk)if(aresetn)begin
  if(aw_stall&&(!m_axi_awvalid||m_axi_awaddr!==prev_aw))$fatal(1,"AW stability");
  if(w_stall&&(!m_axi_wvalid||m_axi_wdata!==prev_w||m_axi_wstrb!==prev_mask))$fatal(1,"W stability");
  if(ar_stall&&(!m_axi_arvalid||m_axi_araddr!==prev_ar))$fatal(1,"AR stability");
  aw_stall<=m_axi_awvalid&&!m_axi_awready;w_stall<=m_axi_wvalid&&!m_axi_wready;ar_stall<=m_axi_arvalid&&!m_axi_arready;
  prev_aw<=m_axi_awaddr;prev_w<=m_axi_wdata;prev_mask<=m_axi_wstrb;prev_ar<=m_axi_araddr;
 end
endmodule
