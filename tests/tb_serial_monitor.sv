`timescale 1ns/1ps
module tb_serial_monitor #(parameter bit RF_TMR=0);
 logic clk=0,rst_n=0,uart_rx=1;wire uart_tx,running,fatal,retire_valid;wire [31:0] pc,corrected_count,uncorrectable_count;
 riscue_monitor_soc #(.WORDS(1024),.CLOCK_HZ(8000000),.BAUD(1000000),.RF_TMR(RF_TMR),.FI_ENABLE(1),.TIMEOUT(256)) dut(.*);
 always #5 clk=~clk;
 wire response_valid,response_error;wire [7:0] response_data;
 riscue_uart_rx #(.CLOCK_HZ(8000000),.BAUD(1000000)) receiver(.clk(clk),.rst_n(rst_n),.rx(uart_tx),.valid(response_valid),.data(response_data),.framing_error(response_error));
 reg [159:0] received;integer received_count=0;integer seq=0;reg [159:0] request,saved;integer i;reg [31:0] instruction[0:5];
 always @(negedge clk)if(response_valid)begin received[received_count*8+:8]=response_data;received_count=received_count+1;end
 task byte_tx(input [7:0] b);integer k;begin
  uart_rx=0;repeat(8)@(negedge clk);
  for(k=0;k<8;k=k+1)begin uart_rx=b[k];repeat(8)@(negedge clk);end
  uart_rx=1;repeat(8)@(negedge clk);
 end endtask
 function automatic [31:0] crc(input [111:0] bytes);
  reg [31:0] c;integer x,y;begin c=32'hffffffff;for(x=0;x<14;x=x+1)begin c=c^bytes[x*8+:8];for(y=0;y<8;y=y+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;end crc=~c;end
 endfunction
 reg driver_start=0;reg [159:0] driver_frame;reg [7:0] driver_expected;integer driver_k;
 // One physical driver coroutine keeps Verilator compilation small.
 initial forever begin
  wait(driver_start);
  received_count=0;received=0;
  for(driver_k=0;driver_k<20;driver_k=driver_k+1)byte_tx(driver_frame[driver_k*8+:8]);
  wait(received_count==20);repeat(12)@(negedge clk);
  if(received[15:0]!=16'ha55a||received[23:16]!=driver_frame[23:16]||received[63:32]!=driver_frame[63:32]||received[31:24]!=driver_expected||received[159:128]!=crc(received[127:16]))$fatal(1,"bad reply cmd=%d got=%h expected status=%d",driver_frame[31:24],received,driver_expected);
  driver_start=0;
 end
 task exchange(input [159:0] f,input [7:0] expected);begin
  driver_frame=f;driver_expected=expected;driver_start=1;wait(!driver_start);
 end endtask
 task command(input [7:0] cmd,input [31:0] a,d,x,input [7:0] expected);begin
  request={32'd0,x,d,a,cmd,8'(seq),16'h5aa5};request[159:128]=crc(request[127:16]);seq=(seq+1)&255;exchange(request,expected);
 end endtask
 bit C_MODE;reg [31:0] golden_mask[0:31];reg was_running=0;
 always @(negedge clk)begin
  if(was_running&&!running&&(!dut.core_bridge_idle||!dut.memory_idle))$fatal(1,"unsafe ownership change");
  was_running=running;
 end
 reg [159:0] load_frames[0:1023];reg [31:0] golden[0:31];integer count,entry,finish_pc;
 initial begin
  C_MODE=$test$plusargs("c_program");
  repeat(5)@(negedge clk);rst_n=1;repeat(5)@(negedge clk);
  if(C_MODE)begin
   if(!$value$plusargs("count=%d",count)||!$value$plusargs("entry=%d",entry)||!$value$plusargs("finish_pc=%d",finish_pc))$fatal;
   $readmemh("build/monitor-c/load.hex",load_frames,0,count-1);$readmemh("build/axi-c/smoke.expected",golden);$readmemh("build/monitor-c/golden.mask",golden_mask);
   for(i=0;i<count;i=i+1)exchange(load_frames[i],0);
   seq=count&255;command(4,entry,0,0,0);
   wait(retire_valid&&dut.cpu.retire_pc==finish_pc);
   command(5,0,0,0,0);
   for(i=0;i<32;i=i+1)if(golden_mask[i]!=0)begin
    command(2,4032+4*i,0,0,0);if(received[95:64]!==golden[i])$fatal(1,"C mailbox %0d expected %h got %h",i,golden[i],received[95:64]);
   end
   if(fatal)$fatal(1,"C program fatal");
   $display("PASS serial ELF C smoke RF_TMR=%0d loaded_words=%0d",RF_TMR,count);$finish;
  end else begin
  command(0,0,0,0,0);if(received[95:64]!=32'h52495343||received[127:96]!=4096)$fatal;
  command(3,256,32'h11223344,0,0);saved=request;
  exchange(saved,0); // duplicate write returns cached response
  saved[64]=~saved[64];saved[159:128]=crc(saved[127:16]);exchange(saved,8);
  command(2,256,0,0,0);if(received[95:64]!=32'h11223344)$fatal;
  saved=request;saved[31:24]=3;saved[95:64]=0;exchange(saved,2); // bad CRC has no write
  command(2,256,0,0,0);if(received[95:64]!=32'h11223344)$fatal;
  command(2,3,0,0,3);command(3,4096,0,0,3);command(99,0,0,0,1);
  // Partial packet and idle timeout must resynchronize.
  byte_tx(8'ha5);byte_tx(8'h5a);byte_tx(0);repeat(400)@(negedge clk);command(0,0,0,0,0);
  command(6,256,1,0,0);exchange(request,0);command(2,256,0,0,0);if(received[95:64]!=32'h11223344||corrected_count==0)$fatal(1,"ECC correction missing");
  command(6,256,3,0,0);command(2,256,0,0,5);command(4,0,0,0,5);
  command(7,0,0,0,0);command(3,256,32'h11223344,0,0);command(2,256,0,0,0);
  // Start at nonzero halfword-aligned address. Instructions straddle words.
  // addi x1,x0,42; addi x2,x0,512; sw x1,0(x2); jal x0,0
  command(3,64,32'h00930001,0,0);command(3,68,32'h011302a0,0,0);
  command(3,72,32'h20232000,0,0);command(3,76,32'h006f0011,0,0);command(3,80,0,0,0);
  command(4,66,0,0,0);exchange(request,0);if(!running)$fatal(1,"not running");
  command(3,512,99,0,4);command(5,0,0,0,0);if(running)$fatal(1,"stop failed");
  command(2,512,0,0,0);if(received[95:64]!=42)$fatal(1,"program result %h",received[95:64]);
  command(4,66,0,0,0);
  force dut.core_bridge_idle=0;command(5,0,0,0,6);if(!running)$fatal(1,"timeout changed ownership");release dut.core_bridge_idle;
  command(5,0,0,0,0);
  force dut.m_arready=0;command(2,512,0,0,6);release dut.m_arready;
  command(1,0,0,0,0);if(!received[101])$fatal(1,"host timeout not locked");
  command(3,512,99,0,4);

  $display("PASS serial monitor RF_TMR=%0d: UART CRC replay timeout ECC DED recovery nonzero straddled entry run-stop-read",RF_TMR);$finish;
 end
 end
 initial begin #10000000;$fatal(1,"monitor test timeout state=%d received=%d",dut.monitor.state,received_count);end
endmodule
