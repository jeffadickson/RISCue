// AXI4-Lite slave backed by the reference SECDED RAM and protected control.
module riscue_axi_ecc_ram #(parameter integer WORDS=1024,parameter INIT_FILE="",parameter logic [31:0] BASE_ADDRESS=0,parameter bit FI_ENABLE=0)(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 CLK CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET aresetn" *) input logic aclk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 RESET RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input logic aresetn,
 input logic memory_reset,scrub_enable,output wire idle,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR", X_INTERFACE_PARAMETER="PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 32, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1" *) input logic [31:0] s_axi_awaddr,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *) input logic [2:0] s_axi_awprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input logic s_axi_awvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output logic s_axi_awready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) input logic [31:0] s_axi_wdata,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) input logic [3:0] s_axi_wstrb,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) input logic s_axi_wvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) output logic s_axi_wready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) output logic [1:0] s_axi_bresp,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) output logic s_axi_bvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) input logic s_axi_bready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) input logic [31:0] s_axi_araddr,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *) input logic [2:0] s_axi_arprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input logic s_axi_arvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output logic s_axi_arready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) output logic [31:0] s_axi_rdata,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) output logic [1:0] s_axi_rresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) output logic s_axi_rvalid,(* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) input logic s_axi_rready,
 input logic fi_valid,input logic [3:0] fi_target,input logic [31:0] fi_index,input logic [511:0] fi_mask,output logic fi_ack,
 output logic fatal,corrected_event,disagreement_event,event_valid,
 output logic [31:0] corrected_count,uncorrectable_count,disagreement_count,fatal_count,
 output logic [31:0] last_error_address,output logic [5:0] last_error_syndrome
);
 import ft_pkg::*;
 initial if(WORDS<=0||BASE_ADDRESS[1:0]!=0)$fatal(1,"Invalid AXI ECC RAM window");
 localparam logic [3:0] IDLE=0,WAIT_RAM=3,DROP_RAM=5;
 typedef struct packed {
  logic [3:0] phase;
  logic aw_hold,w_hold,bvalid,rvalid,write,dead;
  logic [31:0] awaddr,wdata,address,data;
  logic [3:0] strobe,mask;
  logic [1:0] bresp,rresp;
  logic [31:0] response;
  logic [31:0] corrected,uncorrectable,disagreement,fatals,last_address;
  logic [5:0] syndrome;
 } state_t;
 (* keep="true",DONT_TOUCH="TRUE" *) state_t s0,s1,s2;
 state_t s,n;
 wire state_bad=(s0!=s1)&&(s0!=s2)&&(s1!=s2);
 wire state_dis=(s0!=s1)||(s0!=s2);
 wire ram_fi_ack;
 wire valid_fi=(fi_target==8&&fi_index<WORDS&&(fi_mask>>39)==0)||(fi_target>=9&&fi_target<=11&&fi_index==0&&(fi_mask>>35)==0);
 assign fi_ack=ram_fi_ack;
 wire ram_ready,ram_error,ram_fatal,ram_ce,ram_dis;
 wire [7:0] ram_flags;wire [31:0] ram_address;wire [5:0] ram_syndrome;
 wire [38:0] ram_data;
 ecc_result_t decoded;
 wire ram_req=aresetn&&!memory_reset&&!s.dead&&!state_bad&&s.phase==WAIT_RAM;
 wire [38:0] address_code=ecc_encode(s.address-BASE_ADDRESS);
 wire [38:0] data_code=ecc_encode(s.data);
 wire [38:0] control_code=ecc_encode(s.write?(32'h10|{28'b0,s.mask}):32'd0);
 assign idle=s.phase==IDLE&&!s.aw_hold&&!s.w_hold&&!s.bvalid&&!s.rvalid&&!s.dead&&!state_bad;
 assign s=(s0&s1)|(s0&s2)|(s1&s2);
 assign s_axi_awready=aresetn&&!memory_reset&&!s.dead&&!state_bad&&s.phase==IDLE&&!s.aw_hold&&!s.bvalid&&!s.rvalid;
 assign s_axi_wready=aresetn&&!memory_reset&&!s.dead&&!state_bad&&s.phase==IDLE&&!s.w_hold&&!s.bvalid&&!s.rvalid;
 // Reserve arbitration for a partially accepted write; complete writes win.
 assign s_axi_arready=aresetn&&!memory_reset&&!s.dead&&!state_bad&&s.phase==IDLE&&!s.aw_hold&&!s.w_hold&&!s.bvalid&&!s.rvalid&&!s_axi_awvalid&&!s_axi_wvalid;
 assign s_axi_bvalid=aresetn&&s.bvalid;assign s_axi_bresp=s.bresp;
 assign s_axi_rvalid=aresetn&&s.rvalid;assign s_axi_rresp=s.rresp;assign s_axi_rdata=s.response;
 assign fatal=s.dead||state_bad||ram_fatal;
 assign corrected_event=ram_ce;assign disagreement_event=state_dis||ram_dis;
 assign event_valid=(ram_flags!=0)||state_dis||state_bad;
 assign corrected_count=s.corrected;assign uncorrectable_count=s.uncorrectable;
 assign disagreement_count=s.disagreement;assign fatal_count=s.fatals;
 assign last_error_address=s.last_address;assign last_error_syndrome=s.syndrome;
 ft_ecc_ram #(.WORDS(WORDS),.INIT_FILE(INIT_FILE),.FI_ENABLE(FI_ENABLE),.FAIL_STOP_DED(1),.EXTERNAL_SCRUB_CONTROL(1)) ram(
  .clk(aclk),.rst_n(aresetn&&!memory_reset),.req(ram_req),.scrub_enable(scrub_enable&&!s.dead&&!state_bad),
  .addr_code(address_code),.wdata_code(data_code),.ctrl_code(control_code),.ready(ram_ready),.error(ram_error),.rdata_code(ram_data),
  .corrected_event(ram_ce),.fatal(ram_fatal),.disagreement_event(ram_dis),
  .fi_valid(fi_valid&&aresetn&&!memory_reset&&valid_fi&&fi_mask!=0),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(ram_fi_ack),
  .event_flags(ram_flags),.event_address(ram_address),.event_syndrome(ram_syndrome));
 always @* begin
  n=s;decoded=ecc_decode(ram_data);
  if(s_axi_bvalid&&s_axi_bready)n.bvalid=0;
  if(s_axi_rvalid&&s_axi_rready)n.rvalid=0;
  if(ram_flags[0])n.corrected=s.corrected+1;
  if(ram_flags[1]||(ram_flags[3]&&ram_syndrome!=0))n.uncorrectable=s.uncorrectable+1;
  if(state_dis||ram_flags[2])n.disagreement=s.disagreement+1;
  if(ram_flags[3]||(state_bad&&!s.dead))n.fatals=s.fatals+1;
  if(ram_flags!=0)begin n.last_address=BASE_ADDRESS+ram_address;n.syndrome=ram_syndrome;end
  if(memory_reset&&(s.phase!=IDLE||s.aw_hold||s.w_hold||s.bvalid||s.rvalid))begin n.dead=1;end
  else if(state_bad)begin n.dead=1;end
  else if(!s.dead)case(s.phase)
   IDLE:begin
    if(s_axi_awvalid&&s_axi_awready)begin n.aw_hold=1;n.awaddr=s_axi_awaddr;end
    if(s_axi_wvalid&&s_axi_wready)begin n.w_hold=1;n.wdata=s_axi_wdata;n.strobe=s_axi_wstrb;end
    if(s.aw_hold&&s.w_hold)begin
     n.aw_hold=0;n.w_hold=0;n.write=1;n.address=s.awaddr;n.data=s.wdata;n.mask=s.strobe;
     if(s.awaddr[1:0]!=0||s.awaddr<BASE_ADDRESS||(s.awaddr-BASE_ADDRESS)/4>=WORDS)begin n.bvalid=1;n.bresp=3;end
     else if(s.strobe==0)begin n.bvalid=1;n.bresp=0;end
     else n.phase=WAIT_RAM;
    end else if(s_axi_arvalid&&s_axi_arready)begin
     n.write=0;n.address=s_axi_araddr;n.mask=0;
     if(s_axi_araddr[1:0]!=0||s_axi_araddr<BASE_ADDRESS||(s_axi_araddr-BASE_ADDRESS)/4>=WORDS)begin n.rvalid=1;n.rresp=3;n.response=0;end
     else n.phase=WAIT_RAM;
    end
   end
   WAIT_RAM:if(ram_ready||ram_fatal)begin
    if(s.write)begin n.bvalid=1;n.bresp=(ram_error||ram_fatal)?2:0;end
    else begin n.rvalid=1;n.rresp=(ram_error||ram_fatal||decoded.uncorrectable)?2:0;n.response=(ram_error||ram_fatal)?0:decoded.data;end
    n.phase=DROP_RAM;
   end
   DROP_RAM:if(!ram_ready)n.phase=IDLE;
   default:n.dead=1;
  endcase
 end
 always @(posedge aclk)begin
  if(!aresetn)begin s0<='0;s1<='0;s2<='0;end
  else begin s0<=n;s1<=n;s2<=n;end
 end
endmodule
