// Single-hart minimal RISC-V Debug 0.13 register interface. No program buffer.
// Commands are captured in a voted/repaired TMR record. SBA is halted-only.
module riscue_debug_module #(parameter integer TIMEOUT=1024)(
 input logic clk,rst_n,input logic dmi_valid,dmi_write,input logic [6:0] dmi_addr,
 input logic [31:0] dmi_wdata,output logic [31:0] dmi_rdata,
 input logic hart_halted,hart_resumeack,hart_fatal,
 output logic haltreq,resumereq,ndmreset,
 output logic reg_valid,reg_write,output logic [15:0] regno,output logic [31:0] reg_wdata,
 input logic reg_ready,reg_error,input logic [31:0] reg_rdata,
 output logic bus_req,output logic [31:0] bus_addr,bus_wdata,output logic [3:0] bus_mask,
 output logic bus_write,input logic bus_ready,bus_error,input logic [31:0] bus_rdata,
 output logic fault,disagreement
);
 typedef struct packed {
  logic failed;
  logic active,halt,reset_halt,reset,have_reset,resume,resume_ack,reset_pending;
  logic busy;logic [2:0] cmderr;logic [31:0] command,data;
  logic sb_busy,sb_write,sb_readaddr,sb_readdata,sb_autoinc,sb_busyerror;
  logic [2:0] sb_access,sb_error;logic [31:0] sb_address,sb_data,ticks;
 } state_t;
 (* keep="true",DONT_TOUCH="TRUE" *) state_t a,b,c;
 state_t s,n;
 wire bad=(a!=b)&&(a!=c)&&(b!=c);
 logic start_read,start_write;
 always_comb begin
  s=(a&b)|(a&c)|(b&c);n=s;
  disagreement=(a!=b)||(a!=c);fault=bad||s.failed;
  if(bad)n.failed=1;
  haltreq=s.active&&(s.halt||s.reset_halt&&s.reset_pending);
  resumereq=s.active&&s.resume&&!fault&&!s.sb_busy&&!s.busy;ndmreset=s.active&&s.reset&&!fault;
  reg_valid=s.active&&s.busy&&!fault;reg_write=s.command[16];regno=s.command[15:0];reg_wdata=s.data;
  bus_req=s.active&&s.sb_busy&&!fault&&!hart_fatal&&!s.reset;
  bus_addr=s.sb_address&32'hfffffffc;
  bus_mask=(s.sb_access==0?4'b0001:s.sb_access==1?4'b0011:4'b1111)<<s.sb_address[1:0];
  bus_wdata=s.sb_data<<(8*s.sb_address[1:0]);bus_write=s.sb_write;
  start_read=0;start_write=0;dmi_rdata=0;
  case(dmi_addr)
   7'h04:dmi_rdata=s.data;
   7'h10:dmi_rdata={s.halt,s.resume,28'b0,s.reset,s.active};
   7'h11:begin
    dmi_rdata=32'h000000a2; // authenticated, hasresethaltreq, version 0.13
    dmi_rdata[19:18]={2{s.have_reset}};dmi_rdata[17:16]={2{s.resume_ack}};
    dmi_rdata[13:12]={2{s.reset||hart_fatal||fault}};
    dmi_rdata[11:10]={2{!hart_halted&&!s.reset&&!hart_fatal&&!fault}};
    dmi_rdata[9:8]={2{hart_halted&&!s.reset&&!hart_fatal&&!fault}};
   end
   7'h16:dmi_rdata={19'b0,s.busy,1'b0,s.cmderr,4'b0,4'd1};
   7'h38:begin
    dmi_rdata=32'h20000407;
    dmi_rdata[22]=s.sb_busyerror;dmi_rdata[21]=s.sb_busy;dmi_rdata[20]=s.sb_readaddr;
    dmi_rdata[19:17]=s.sb_access;dmi_rdata[16]=s.sb_autoinc;dmi_rdata[15]=s.sb_readdata;dmi_rdata[14:12]=s.sb_error;
   end
   7'h39:dmi_rdata=s.sb_address;
   7'h3c:dmi_rdata=s.sb_data;
   default:dmi_rdata=0;
  endcase
  if(s.reset)begin n.have_reset=1;n.reset_pending=1;n.busy=0;n.sb_busy=0;n.ticks=0;end
  else if(hart_halted)n.reset_pending=0;
  if(s.resume&&hart_resumeack)begin n.resume=0;n.resume_ack=1;end
  if(s.busy&&reg_ready)begin
   n.busy=0;
   if(reg_error)n.cmderr=hart_halted?3:4;
   else if(!s.command[16])n.data=reg_rdata;
  end
  if(s.sb_busy)begin
   n.ticks=s.ticks+1;
   if(bus_ready)begin
    n.sb_busy=0;n.ticks=0;
    if(bus_error)n.sb_error=2;
    else begin
     if(!s.sb_write)n.sb_data=(bus_rdata>>(8*s.sb_address[1:0]))&(s.sb_access==0?32'hff:s.sb_access==1?32'hffff:32'hffffffff);
     if(s.sb_autoinc)n.sb_address=s.sb_address+(32'b1<<s.sb_access);
    end
   end else if(hart_fatal||s.ticks>=TIMEOUT-1)begin n.sb_busy=0;n.sb_error=1;end
  end
  if(dmi_valid&&!fault)begin
   if(dmi_write&&dmi_addr==7'h10)begin
    if(!dmi_wdata[0])begin n='0;n.sb_access=2;n.have_reset=1;end
    else begin
     n.active=1;n.halt=dmi_wdata[31];n.reset=dmi_wdata[1];
     if(dmi_wdata[28])n.have_reset=0;
     if(dmi_wdata[3])n.reset_halt=1;
     if(dmi_wdata[2])n.reset_halt=0;
     if(dmi_wdata[30]&&!dmi_wdata[31])begin n.resume=hart_halted;n.resume_ack=!hart_halted;end
    end
   end else if(s.active)begin
    if(dmi_write)case(dmi_addr)
     7'h04:if(s.busy)n.cmderr=1;else n.data=dmi_wdata;
     7'h16:if(!s.busy)n.cmderr=s.cmderr&~dmi_wdata[10:8];
     7'h17:begin
      if(s.busy)n.cmderr=1;
      else if(s.cmderr==0)begin
       if(dmi_wdata[31:24]!=0||dmi_wdata[23:20]!=2||dmi_wdata[19:18]!=0)n.cmderr=2;
       else if(!hart_halted||hart_fatal)n.cmderr=4;
       else if(dmi_wdata[17])begin n.command=dmi_wdata;n.busy=1;end
      end
     end
     7'h38:begin
      if(dmi_wdata[22])n.sb_busyerror=0;
      if(!s.sb_busy)begin
       n.sb_error=s.sb_error&~dmi_wdata[14:12];n.sb_access=dmi_wdata[19:17];
       n.sb_readaddr=dmi_wdata[20];n.sb_readdata=dmi_wdata[15];n.sb_autoinc=dmi_wdata[16];
      end else n.sb_busyerror=1;
     end
     7'h39:if(s.sb_busy)n.sb_busyerror=1;else begin n.sb_address=dmi_wdata;start_read=s.sb_readaddr;end
     7'h3c:if(s.sb_busy)n.sb_busyerror=1;else begin n.sb_data=dmi_wdata;start_write=1;end
     default:begin end
    endcase
    else if(dmi_addr==7'h04&&s.busy)n.cmderr=1;
    else if(dmi_addr==7'h3c)begin
     if(s.sb_busy)n.sb_busyerror=1;else start_read=s.sb_readdata;
    end
   end
  end
  if((start_read||start_write)&&n.sb_error==0&&!n.sb_busyerror)begin
   if(!hart_halted||hart_fatal||s.reset)n.sb_error=7;
   else if(n.sb_access>2)n.sb_error=4;
   else if((n.sb_address&((32'b1<<n.sb_access)-1))!=0)n.sb_error=3;
   else begin n.sb_busy=1;n.sb_write=start_write;n.ticks=0;end
  end
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin a<='0;b<='0;c<='0;a.sb_access<=2;b.sb_access<=2;c.sb_access<=2;a.have_reset<=1;b.have_reset<=1;c.have_reset<=1;end
  else begin a<=n;b<=n;c<=n;end
 end
endmodule
