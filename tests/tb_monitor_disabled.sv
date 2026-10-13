`timescale 1ns/1ps
module tb_monitor_disabled;
 reg clk=0,rst_n=0,uart_rx=1;wire uart_tx,fi_valid,req;
 always #5 clk=~clk;
 riscue_serial_monitor #(.CLOCK_HZ(8000000),.BAUD(1000000),.FI_ENABLE(0)) dut(
 .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),.core_quiescent(1'b1),.core_bridge_idle(1'b1),.core_fatal(1'b0),.memory_fatal(1'b0),.memory_idle(1'b1),
 .pc(32'd0),.trap_cause(32'd0),.trap_value(32'd0),.retired_count(32'd0),.corrected_count(32'd0),.uncorrectable_count(32'd0),.disagreement_count(32'd0),.fatal_count(32'd0),.last_error_address(32'd0),.last_error_syndrome(6'd0),
 .req(req),.ready(1'b0),.error(1'b0),.bridge_idle(1'b1),.bridge_fatal(1'b0),.rdata_code(39'd0),.fi_valid(fi_valid),.fi_ack(1'b0));
 wire valid;wire [7:0] data;reg [159:0] response=0;integer count=0;
 riscue_uart_rx #(.CLOCK_HZ(8000000),.BAUD(1000000)) rx(.clk(clk),.rst_n(rst_n),.rx(uart_tx),.valid(valid),.data(data));
 always @(negedge clk)begin if(valid)begin response[count*8+:8]=data;count=count+1;end if(fi_valid||req)$fatal(1,"disabled injection had effects");end
 task send_byte(input [7:0] b);integer k;begin uart_rx=0;repeat(8)@(negedge clk);for(k=0;k<8;k=k+1)begin uart_rx=b[k];repeat(8)@(negedge clk);end uart_rx=1;repeat(8)@(negedge clk);end endtask
 reg [159:0] packet;integer i;
 initial begin
  packet=160'hbdf4a68400000000000000010000000006005aa5;
  repeat(5)@(negedge clk);rst_n=1;repeat(5)@(negedge clk);
  for(i=0;i<20;i=i+1)send_byte(packet[i*8+:8]);
  wait(count==20);if(response[31:24]!=7)$fatal(1,"FI disabled status");$display("PASS monitor injection disabled");$finish;
 end
 initial begin #100000;$fatal(1,"disabled monitor timeout");end
endmodule
