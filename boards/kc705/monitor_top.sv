// KC705: UART monitor by default; original VIO/ILA laboratory build retained.
module riscue_kc705 #(parameter integer WORDS=1024,CLK_DIV=100,parameter bit RF_TMR=0,FI_ENABLE=0,INSTRUMENTED=0,parameter INIT_FILE="firmware.hex")(
 input wire sys_clk_p,sys_clk_n,cpu_reset,fault_button,uart_rx,output wire uart_tx,output wire [7:0] led
);
 generate if(INSTRUMENTED)begin:legacy_lab
  riscue_kc705_legacy #(.WORDS(WORDS),.CLK_DIV(CLK_DIV),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.INSTRUMENTED(1),.INIT_FILE(INIT_FILE)) legacy(
   .sys_clk_p(sys_clk_p),.sys_clk_n(sys_clk_n),.cpu_reset(cpu_reset),.fault_button(fault_button),.uart_tx(uart_tx),.led(led));
 end else begin:development
  wire input_clk,feedback,feedback_buf,clock_raw,clk,locked;
  IBUFDS clock_input(.I(sys_clk_p),.IB(sys_clk_n),.O(input_clk));
  MMCME2_BASE #(.CLKIN1_PERIOD(5.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(5.0),.CLKOUT0_DIVIDE_F(CLK_DIV*1.0),.BANDWIDTH("OPTIMIZED")) clock_mmcm(
   .CLKIN1(input_clk),.CLKFBIN(feedback_buf),.RST(cpu_reset),.PWRDWN(1'b0),.CLKFBOUT(feedback),.CLKOUT0(clock_raw),.LOCKED(locked));
  BUFG clock_feedback(.I(feedback),.O(feedback_buf));BUFG core_clock(.I(clock_raw),.O(clk));
  wire raw_reset=cpu_reset||!locked;
  (* ASYNC_REG="TRUE" *) reg [3:0] reset_pipe=0;
  always @(posedge clk or posedge raw_reset)if(raw_reset)reset_pipe<=0;else reset_pipe<={reset_pipe[2:0],1'b1};
  wire rst_n=reset_pipe[3];wire running,fatal,retire_valid;wire [31:0] pc,corrected_count,uncorrectable_count;
  reg [23:0] heartbeat;reg [31:0] activity;
  always @(posedge clk)if(!rst_n)begin heartbeat<=0;activity<=0;end else begin
   heartbeat<=heartbeat+1;if(retire_valid)activity<=1000000000/CLK_DIV/20;else if(activity!=0)activity<=activity-1;
  end
  riscue_monitor_soc #(.WORDS(WORDS),.CLOCK_HZ(1000000000/CLK_DIV),.RF_TMR(RF_TMR),.FI_ENABLE(FI_ENABLE),.INIT_FILE(INIT_FILE)) soc(.*);
  assign led={1'b0,1'b0,uncorrectable_count!=0,corrected_count!=0,fatal,!running,activity!=0,heartbeat[23]};
 end endgenerate
endmodule
