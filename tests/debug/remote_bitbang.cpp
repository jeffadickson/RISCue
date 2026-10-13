// OpenOCD remote_bitbang endpoint connected to actual Verilated JTAG pins.
#include "Vriscue_debug_soc.h"
#include "verilated.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include <poll.h>
#include <cstdlib>
#include <cstdio>
static void cycle(Vriscue_debug_soc &dut) {dut.clk=0;dut.eval();dut.clk=1;dut.eval();}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);Vriscue_debug_soc dut;
 dut.rst_n=0;dut.tck=0;dut.tms=1;dut.tdi=0;dut.external_irq=0;
 for(int i=0;i<8;i++)cycle(dut);dut.rst_n=1;
 int port=argc>1?atoi(argv[1]):9824;
 int server=socket(AF_INET,SOCK_STREAM,0),one=1;setsockopt(server,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
 sockaddr_in addr{};addr.sin_family=AF_INET;addr.sin_addr.s_addr=htonl(INADDR_LOOPBACK);addr.sin_port=htons(port);
 if(bind(server,(sockaddr*)&addr,sizeof(addr))||listen(server,1)){perror("listen");return 1;}
 printf("RISCue remote_bitbang listening on localhost:%d\n",port);fflush(stdout);
 int fd=accept(server,nullptr,nullptr);if(fd<0)return 1;
 setsockopt(fd,IPPROTO_TCP,TCP_NODELAY,&one,sizeof(one));
 bool quit=false;
 while(!quit){
  pollfd p{fd,POLLIN,0};int available=poll(&p,1,0);
  if(available<0)break;
  if(available&&p.revents&POLLIN){char commands[4096];int n=read(fd,commands,sizeof(commands));if(n<=0)break;
   for(int j=0;j<n;j++){char c=commands[j];
    if(c>='0'&&c<='7'){int v=c-'0';dut.tck=(v>>2)&1;dut.tms=(v>>1)&1;dut.tdi=v&1;dut.eval();}
    else if(c=='R'){char r=dut.tdo?'1':'0';if(write(fd,&r,1)!=1)quit=true;}
    else if(c=='Q')quit=true;
    else if(c=='r'||c=='s'||c=='t'||c=='u'){/* reset pins absent: TAP reset uses TMS */}
    for(int i=0;i<4;i++)cycle(dut);
   }
  }else for(int i=0;i<64;i++)cycle(dut);
 }
 close(fd);close(server);dut.final();return 0;
}
