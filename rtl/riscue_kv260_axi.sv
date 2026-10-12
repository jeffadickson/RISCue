// ARM lab control over AXI4-Lite. RUN=0 resets the hart, not a debug halt.
module riscue_kv260_axi #(parameter integer WORDS=8192,CLOCK_HZ=10000000,parameter bit RF_TMR=0,FI_ENABLE=1)(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 CLK CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET aresetn" *) input logic aclk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 RESET RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input logic aresetn,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR", X_INTERFACE_PARAMETER="PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 18, HAS_BURST 0, HAS_LOCK 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1" *) input logic [17:0] s_axi_awaddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *) input logic [2:0] s_axi_awprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input logic  s_axi_awvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output logic  s_axi_awready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) input logic [31:0] s_axi_wdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) input logic [3:0] s_axi_wstrb,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) input logic  s_axi_wvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) output logic  s_axi_wready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) output logic [1:0] s_axi_bresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) output logic  s_axi_bvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) input logic  s_axi_bready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) input logic [17:0] s_axi_araddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *) input logic [2:0] s_axi_arprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input logic  s_axi_arvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output logic  s_axi_arready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) output logic [31:0] s_axi_rdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) output logic [1:0] s_axi_rresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) output logic  s_axi_rvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) input logic  s_axi_rready
);
 import riscue_pipeline_pkg::*;
 typedef struct packed {
  logic run,irq,arm,token,memory_reset,dead;
  logic aw_hold,w_hold,bvalid,rvalid,mem_wait,mem_we;
  logic [1:0] bresp,rresp;
  logic [17:0] awaddr;
  logic [31:0] wdata,rdata,mem_addr,mem_wdata,mem_wait_count;
  logic [3:0] wstrb,mem_mask;
  logic [3:0] target;
  logic [31:0] index,delay,gap,count,trigger_pc,step,command_flags;
  logic [511:0] mask;
  logic [31:0] pc,cause,tval,corrected,uncorrectable,disagreement,fatal_count,last_insn;
  logic [15:0] flags;
  logic observed_fatal,observed_trap;
  logic [63:0] retired;
 } bridge_t;
 (* keep="true",DONT_TOUCH="TRUE" *) bridge_t c0,c1,c2;
 bridge_t s,n;
 logic bridge_bad,bridge_dis,core_run;
 wire halted,fatal,trap,retire_valid,fi_ack,event_valid,host_ready,host_error;
 wire [31:0] pc,cause,tval,retire_pc,retire_insn,corrected_count,uncorrectable_count,disagreement_count,fatal_count,host_rdata;
 wire [15:0] flags;
 wire fi_valid;wire [3:0] fi_target;wire [31:0] fi_index;wire [511:0] fi_mask;
 wire busy,done_toggle,controller_disagreement,controller_error_sticky;
 wire [7:0] status;wire [15:0] accepted,attempted;
 wire [31:0] last_pc;wire [63:0] last_cycle,trigger_cycle;
 wire [3:0] write_strobe=s.wstrb;
 logic [31:0] value,byte_mask,merged,read_value;
 integer reg_width;
 fi_campaign_controller #(.WORDS(WORDS),.RF_TMR(RF_TMR)) injector(
  .clk(aclk),.rst_n(aresetn),.arm(s.arm&&!bridge_bad),.request_toggle(s.token),.core_reset(!core_run),.core_fatal(fatal),.external_trigger(s.irq),
  .command_target(s.target),.command_index(s.index),.command_mask(s.mask),.command_delay(s.delay),.command_gap(s.gap),
  .command_index_step(s.step),.command_trigger_pc(s.trigger_pc),.command_count(s.count[15:0]),.command_trigger_kind(s.command_flags[1:0]),
  .command_rotate(s.command_flags[2]),.command_stop_on_fatal(s.command_flags[3]),.retire_valid(retire_valid),.retire_pc(retire_pc),.pc(pc),
  .fi_ack(fi_ack),.fi_valid(fi_valid),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),
  .busy(busy),.done_toggle(done_toggle),.controller_disagreement(controller_disagreement),.controller_error_sticky(controller_error_sticky),
  .status(status),.accepted(accepted),.attempted(attempted),.last_pc(last_pc),.last_cycle(last_cycle),.trigger_cycle(trigger_cycle));
 riscue_axi_soc #(.WORDS(WORDS),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE)) soc(
  .clk(aclk),.rst_n(aresetn),.core_run(core_run),.memory_reset(s.memory_reset),.external_irq(s.irq),
  .host_req(s.mem_wait&&!core_run&&!bridge_bad),.host_we(s.mem_we),.host_address(s.mem_addr),.host_wdata(s.mem_wdata),.host_mask(s.mem_mask),
  .host_ready(host_ready),.host_error(host_error),.host_rdata(host_rdata),
  .halted(halted),.fatal(fatal),.trap(trap),.pc(pc),.trap_cause(cause),.trap_value(tval),
  .retire_valid(retire_valid),.retire_pc(retire_pc),.retire_insn(retire_insn),.fi_valid(fi_valid&&FI_ENABLE),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(fi_ack),
  .event_valid(event_valid),.sticky_flags(flags),.corrected_count(corrected_count),.uncorrectable_count(uncorrectable_count),.disagreement_count(disagreement_count),.fatal_count(fatal_count));
 function automatic [31:0] merge_bytes(input [31:0] old_value,new_value,input [3:0] strobe);
  logic [31:0] v;
  begin v=old_value;for(integer b=0;b<4;b=b+1)if(strobe[b])v[b*8+:8]=new_value[b*8+:8];merge_bytes=v;end
 endfunction
 always_comb begin
  s=(c0&c1)|(c0&c2)|(c1&c2);n=s;n.memory_reset=0;
  bridge_dis=c0!=c1||c0!=c2;bridge_bad=s.dead||((c0!=c1)&&(c0!=c2)&&(c1!=c2));
  core_run=aresetn&&s.run&&!bridge_bad;
  s_axi_awready=aresetn&&!s.aw_hold&&!s.bvalid&&!s.mem_wait&&!bridge_bad;
  s_axi_wready=aresetn&&!s.w_hold&&!s.bvalid&&!s.mem_wait&&!bridge_bad;
  s_axi_arready=aresetn&&!s.rvalid&&!s.mem_wait&&!s.aw_hold&&!s.w_hold&&!s.bvalid&&!bridge_bad;
  s_axi_bvalid=aresetn&&s.bvalid;s_axi_bresp=s.bresp;
  s_axi_rvalid=aresetn&&s.rvalid;s_axi_rdata=s.rdata;s_axi_rresp=s.rresp;
  value=s.wdata;byte_mask=0;merged=0;read_value=0;reg_width=0;
  if(core_run)begin
   n.pc=pc;n.cause=cause;n.tval=tval;n.flags=flags;n.corrected=corrected_count;n.uncorrectable=uncorrectable_count;
   n.disagreement=disagreement_count;n.fatal_count=fatal_count;n.observed_fatal=s.observed_fatal||fatal;n.observed_trap=s.observed_trap||trap;
   if(retire_valid)begin n.retired=s.retired+1;n.last_insn=retire_insn;end
  end
  if(s.bvalid&&s_axi_bready)n.bvalid=0;
  if(s.rvalid&&s_axi_rready)n.rvalid=0;
  if(s_axi_awvalid&&s_axi_awready)begin n.aw_hold=1;n.awaddr=s_axi_awaddr;end
  if(s_axi_wvalid&&s_axi_wready)begin n.w_hold=1;n.wdata=s_axi_wdata;n.wstrb=s_axi_wstrb;end
  if(s.aw_hold&&s.w_hold&&!s.bvalid&&!s.mem_wait)begin
   n.aw_hold=0;n.w_hold=0;n.bvalid=1;n.bresp=0;
   if(s.awaddr[1:0]!=0)n.bresp=2;
   else if(s.awaddr>=18'h10000&&s.awaddr<18'h10000+WORDS*4)begin
    if(s.run)n.bresp=2;
    else begin n.bvalid=0;n.mem_wait=1;n.mem_we=1;n.mem_addr=s.awaddr-18'h10000;n.mem_wdata=s.wdata;n.mem_mask=s.wstrb;n.mem_wait_count=0;end
   end else case(s.awaddr)
    18'h08:begin
     merged=merge_bytes({29'b0,1'b0,s.irq,s.run},value,s.wstrb);
     if(merged[0]&&merged[2])n.bresp=2;
     else begin
      n.run=merged[0];n.irq=merged[1];n.memory_reset=merged[2];
      if(!merged[0])n.arm=0;
      if(merged[0]&&!s.run)begin n.retired=0;n.observed_fatal=0;n.observed_trap=0;end
     end
    end
    18'h40:n.target=4'(merge_bytes({28'b0,s.target},value,s.wstrb));
    18'h44:n.index=merge_bytes(s.index,value,s.wstrb);
    18'h48:begin merged=merge_bytes({30'b0,s.arm,s.token},value,s.wstrb);n.token=merged[0];n.arm=merged[1];end
    18'h4c:n.delay=merge_bytes(s.delay,value,s.wstrb);
    18'h50:n.count=merge_bytes(s.count,value,s.wstrb);
    18'h54:n.gap=merge_bytes(s.gap,value,s.wstrb);
    18'h58:n.trigger_pc=merge_bytes(s.trigger_pc,value,s.wstrb);
    18'h5c:n.command_flags=merge_bytes(s.command_flags,value,s.wstrb);
    18'h60:n.step=merge_bytes(s.step,value,s.wstrb);
    default:begin
     if(s.awaddr>=18'h80&&s.awaddr<18'hc0)begin
      // Whole packed assignment avoids variable struct-member part-selects.
      for(integer b=0;b<4;b=b+1)if(write_strobe[b])
       n.mask=(n.mask&~(512'hff<<((s.awaddr-18'h80)*8+b*8)))|((512'(value>>(b*8))&512'hff)<<((s.awaddr-18'h80)*8+b*8));
     end else n.bresp=2;
    end
   endcase
  end
  if(s_axi_arvalid&&s_axi_arready)begin
   n.rvalid=1;n.rresp=0;
   if(s_axi_araddr[1:0]!=0)n.rresp=2;
   else if(s_axi_araddr>=18'h10000&&s_axi_araddr<18'h10000+WORDS*4)begin
    if(s.run)n.rresp=2;
    else begin n.rvalid=0;n.mem_wait=1;n.mem_we=0;n.mem_addr=s_axi_araddr-18'h10000;n.mem_wdata=0;n.mem_mask=0;n.mem_wait_count=0;end
   end else case(s_axi_araddr)
    18'h00:read_value=32'h52495343;
    18'h04:read_value=32'h201|(RF_TMR?32'h10000:0)|(FI_ENABLE?32'h20000:0);
    18'h08:read_value={30'b0,s.irq,s.run};
    18'h0c:read_value={bridge_bad,bridge_dis,26'b0,busy,s.observed_trap,s.observed_fatal,s.run};
    18'h10:read_value=s.pc;18'h14:read_value=s.cause;18'h18:read_value=s.tval;18'h1c:read_value={16'b0,s.flags};
    18'h20:read_value=s.corrected;18'h24:read_value=s.uncorrectable;18'h28:read_value=s.disagreement;18'h2c:read_value=s.fatal_count;
    18'h30:read_value=s.retired[31:0];18'h34:read_value=WORDS;18'h38:read_value=CLOCK_HZ;18'h3c:read_value=s.last_insn;
    18'h40:read_value={28'b0,s.target};18'h44:read_value=s.index;18'h48:read_value={30'b0,s.arm,s.token};
    18'h4c:read_value=s.delay;18'h50:read_value=s.count;18'h54:read_value=s.gap;18'h58:read_value=s.trigger_pc;18'h5c:read_value=s.command_flags;18'h60:read_value=s.step;
    18'h64:read_value={controller_error_sticky,controller_disagreement,20'b0,done_toggle,busy,status};
    18'h68:read_value={attempted,accepted};18'h6c:read_value=last_pc;18'h70:read_value=last_cycle[31:0];18'h74:read_value=last_cycle[63:32];
    18'h78:read_value=s.retired[63:32];
    default:if(s_axi_araddr>=18'h80&&s_axi_araddr<18'hc0)read_value=32'(s.mask>>((s_axi_araddr-18'h80)*8));else n.rresp=2;
   endcase
   n.rdata=read_value;
  end
  if(s.mem_wait)begin
   if(host_ready||s.mem_wait_count==1023)begin
    n.mem_wait=0;
    if(s.mem_we)begin n.bvalid=1;n.bresp=host_ready&&!host_error?0:2;end
    else begin n.rvalid=1;n.rdata=host_rdata;n.rresp=host_ready&&!host_error?0:2;end
   end else n.mem_wait_count=s.mem_wait_count+1;
  end
  if(bridge_bad)begin n.dead=1;n.run=0;n.arm=0;n.mem_wait=0;end
 end
 always_ff @(posedge aclk)begin
  if(!aresetn)begin
   c0<='0;c1<='0;c2<='0;
   c0.delay<=1;c1.delay<=1;c2.delay<=1;c0.gap<=2;c1.gap<=2;c2.gap<=2;
   c0.count<=1;c1.count<=1;c2.count<=1;c0.command_flags<=8;c1.command_flags<=8;c2.command_flags<=8;
   c0.mask<=1;c1.mask<=1;c2.mask<=1;c0.target<=8;c1.target<=8;c2.target<=8;
   c0.index<=WORDS-1;c1.index<=WORDS-1;c2.index<=WORDS-1;
  end else begin c0<=n;c1<=n;c2<=n;end
 end
endmodule
