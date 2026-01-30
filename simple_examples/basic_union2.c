#include "test.h"

// 测试使用union访问同一数据的不同方式（Type Punning）
union IpAddress {
    unsigned int address;
    unsigned char octets[4];
};

int main() {
    union IpAddress ip;

    // 模拟 IP: 192.168.1.1 (0xC0A80101)
    // 注意：这里的字节序依赖于具体机器（通常是小端）
    ip.octets[0] = 192; // C0
    ip.octets[1] = 168; // A8
    ip.octets[2] = 1;   // 01
    ip.octets[3] = 1;   // 01

    printf("IP Address individual octets: %d.%d.%d.%d\n", 
           ip.octets[0], ip.octets[1], ip.octets[2], ip.octets[3]);
    
    printf("IP Address combined (hex): 0x%X\n", ip.address);

    ip.address = 0x01020304;
    printf("New IP octets: %d %d %d %d\n", 
           ip.octets[0], ip.octets[1], ip.octets[2], ip.octets[3]);

    return 0;
}

