typedef unsigned int u32;
extern u32 crc16_packet(const unsigned char *data,u32 length,u32 seed);
extern volatile u32 mailbox[];
static const unsigned char check[]="123456789";
static const unsigned char packet[]={0x10,0x20,0x00,0xff,0x7e,0x81};
int main(void) {
    mailbox[1]=crc16_packet(check,9,0xffff);
    mailbox[2]=crc16_packet(check,0,0xffff);
    mailbox[3]=crc16_packet(packet,sizeof packet,0xffff);
    mailbox[0]=0x50415353;
    return 0;
}
