// Board-independent serial development system, CPU and monitor share one RAM.
module riscue_monitor_soc #(parameter integer WORDS=1024,CLOCK_HZ=10000000,BAUD=115200,TIMEOUT=100000,parameter bit RF_TMR=0,FI_ENABLE=0,parameter INIT_FILE="")(
 input wire clk,rst_n,uart_rx,output wire uart_tx,
 output wire running,fatal,retire_valid,output wire [31:0] pc,
 output wire [31:0] corrected_count,uncorrectable_count
);
 wire cpu_resetn,halt_request,core_quiescent,core_bridge_idle,core_fatal,memory_fatal,memory_idle;
 wire [31:0] boot_pc,trap_cause,trap_value,disagreement_count,fatal_count,last_error_address;
 wire [5:0] last_error_syndrome;wire memory_reset,scrub_enable,fi_valid,fi_ack;
 wire [3:0] fi_target;wire [31:0] fi_index;wire [511:0] fi_mask;
 wire req,ready,error,bridge_idle,bridge_fatal;wire [38:0] addr_code,wdata_code,ctrl_code,rdata_code;
 reg [31:0] retired_count;
 assign fatal=core_fatal||memory_fatal||bridge_fatal;
 always @(posedge clk)if(!rst_n||!cpu_resetn)retired_count<=0;else if(retire_valid)retired_count<=retired_count+1;
 wire [31:0] c_awaddr;
 wire [2:0] c_awprot;
 wire c_awvalid;
 wire c_awready;
 wire [31:0] c_wdata;
 wire [3:0] c_wstrb;
 wire c_wvalid;
 wire c_wready;
 wire [1:0] c_bresp;
 wire c_bvalid;
 wire c_bready;
 wire [31:0] c_araddr;
 wire [2:0] c_arprot;
 wire c_arvalid;
 wire c_arready;
 wire [31:0] c_rdata;
 wire [1:0] c_rresp;
 wire c_rvalid;
 wire c_rready;
 wire [31:0] h_awaddr;
 wire [2:0] h_awprot;
 wire h_awvalid;
 wire h_awready;
 wire [31:0] h_wdata;
 wire [3:0] h_wstrb;
 wire h_wvalid;
 wire h_wready;
 wire [1:0] h_bresp;
 wire h_bvalid;
 wire h_bready;
 wire [31:0] h_araddr;
 wire [2:0] h_arprot;
 wire h_arvalid;
 wire h_arready;
 wire [31:0] h_rdata;
 wire [1:0] h_rresp;
 wire h_rvalid;
 wire h_rready;
 wire [31:0] m_awaddr;
 wire [2:0] m_awprot;
 wire m_awvalid;
 wire m_awready;
 wire [31:0] m_wdata;
 wire [3:0] m_wstrb;
 wire m_wvalid;
 wire m_wready;
 wire [1:0] m_bresp;
 wire m_bvalid;
 wire m_bready;
 wire [31:0] m_araddr;
 wire [2:0] m_arprot;
 wire m_arvalid;
 wire m_arready;
 wire [31:0] m_rdata;
 wire [1:0] m_rresp;
 wire m_rvalid;
 wire m_rready;
 assign m_awaddr=running?c_awaddr:h_awaddr;
 assign m_awprot=running?c_awprot:h_awprot;
 assign m_awvalid=running?c_awvalid:h_awvalid;
 assign c_awready=running?m_awready:'0;
 assign h_awready=!running?m_awready:'0;
 assign m_wdata=running?c_wdata:h_wdata;
 assign m_wstrb=running?c_wstrb:h_wstrb;
 assign m_wvalid=running?c_wvalid:h_wvalid;
 assign c_wready=running?m_wready:'0;
 assign h_wready=!running?m_wready:'0;
 assign c_bresp=running?m_bresp:'0;
 assign h_bresp=!running?m_bresp:'0;
 assign c_bvalid=running?m_bvalid:'0;
 assign h_bvalid=!running?m_bvalid:'0;
 assign m_bready=running?c_bready:h_bready;
 assign m_araddr=running?c_araddr:h_araddr;
 assign m_arprot=running?c_arprot:h_arprot;
 assign m_arvalid=running?c_arvalid:h_arvalid;
 assign c_arready=running?m_arready:'0;
 assign h_arready=!running?m_arready:'0;
 assign c_rdata=running?m_rdata:'0;
 assign h_rdata=!running?m_rdata:'0;
 assign c_rresp=running?m_rresp:'0;
 assign h_rresp=!running?m_rresp:'0;
 assign c_rvalid=running?m_rvalid:'0;
 assign h_rvalid=!running?m_rvalid:'0;
 assign m_rready=running?c_rready:h_rready;
 riscue_serial_monitor #(.WORDS(WORDS),.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD),.TIMEOUT(TIMEOUT),.FI_ENABLE(FI_ENABLE)) monitor(.*);
 riscue_axi_core #(.RF_TMR(RF_TMR),.MEMORY_FAULT_INPUT(1),.MONITOR_CONTROL(1)) cpu(
 .aclk(clk),.aresetn(rst_n&&cpu_resetn),.external_irq(1'b0),.external_memory_fault(memory_fatal),
 .halt_request(halt_request),.boot_pc(boot_pc),.quiescent(core_quiescent),.bridge_idle(core_bridge_idle),
 .fatal(core_fatal),.pc(pc),.trap_cause(trap_cause),.trap_value(trap_value),.retire_valid(retire_valid),
 .fi_valid(1'b0),.fi_target(4'd0),.fi_index(32'd0),.fi_mask(512'd0),
 .m_axi_awaddr(c_awaddr),
 .m_axi_awprot(c_awprot),
 .m_axi_awvalid(c_awvalid),
 .m_axi_awready(c_awready),
 .m_axi_wdata(c_wdata),
 .m_axi_wstrb(c_wstrb),
 .m_axi_wvalid(c_wvalid),
 .m_axi_wready(c_wready),
 .m_axi_bresp(c_bresp),
 .m_axi_bvalid(c_bvalid),
 .m_axi_bready(c_bready),
 .m_axi_araddr(c_araddr),
 .m_axi_arprot(c_arprot),
 .m_axi_arvalid(c_arvalid),
 .m_axi_arready(c_arready),
 .m_axi_rdata(c_rdata),
 .m_axi_rresp(c_rresp),
 .m_axi_rvalid(c_rvalid),
 .m_axi_rready(c_rready));
 riscue_axi_master_bridge host_bridge(.clk(clk),.rst_n(rst_n),.core_req(req),.addr_code(addr_code),.wdata_code(wdata_code),.ctrl_code(ctrl_code),
 .core_ready(ready),.core_error(error),.rdata_code(rdata_code),.idle(bridge_idle),.fatal(bridge_fatal),
 .m_axi_awaddr(h_awaddr),
 .m_axi_awprot(h_awprot),
 .m_axi_awvalid(h_awvalid),
 .m_axi_awready(h_awready),
 .m_axi_wdata(h_wdata),
 .m_axi_wstrb(h_wstrb),
 .m_axi_wvalid(h_wvalid),
 .m_axi_wready(h_wready),
 .m_axi_bresp(h_bresp),
 .m_axi_bvalid(h_bvalid),
 .m_axi_bready(h_bready),
 .m_axi_araddr(h_araddr),
 .m_axi_arprot(h_arprot),
 .m_axi_arvalid(h_arvalid),
 .m_axi_arready(h_arready),
 .m_axi_rdata(h_rdata),
 .m_axi_rresp(h_rresp),
 .m_axi_rvalid(h_rvalid),
 .m_axi_rready(h_rready));
 riscue_axi_ecc_ram #(.WORDS(WORDS),.INIT_FILE(INIT_FILE),.FI_ENABLE(FI_ENABLE)) memory(
 .aclk(clk),.aresetn(rst_n),.memory_reset(memory_reset),.scrub_enable(scrub_enable),.idle(memory_idle),
 .fatal(memory_fatal),.corrected_count(corrected_count),.uncorrectable_count(uncorrectable_count),
 .disagreement_count(disagreement_count),.fatal_count(fatal_count),.last_error_address(last_error_address),.last_error_syndrome(last_error_syndrome),
 .fi_valid(fi_valid),.fi_target(fi_target),.fi_index(fi_index),.fi_mask(fi_mask),.fi_ack(fi_ack),
 .s_axi_awaddr(m_awaddr),
 .s_axi_awprot(m_awprot),
 .s_axi_awvalid(m_awvalid),
 .s_axi_awready(m_awready),
 .s_axi_wdata(m_wdata),
 .s_axi_wstrb(m_wstrb),
 .s_axi_wvalid(m_wvalid),
 .s_axi_wready(m_wready),
 .s_axi_bresp(m_bresp),
 .s_axi_bvalid(m_bvalid),
 .s_axi_bready(m_bready),
 .s_axi_araddr(m_araddr),
 .s_axi_arprot(m_arprot),
 .s_axi_arvalid(m_arvalid),
 .s_axi_arready(m_arready),
 .s_axi_rdata(m_rdata),
 .s_axi_rresp(m_rresp),
 .s_axi_rvalid(m_rvalid),
 .s_axi_rready(m_rready));
endmodule
