#include "test.h"

// 测试复杂的位域和枚举组合
struct PackedData {
    unsigned int flag1 : 1;
    unsigned int flag2 : 1;
    unsigned int count : 6;
    unsigned int type  : 4;
    unsigned int mode  : 4;
    unsigned int reserved : 16;
};

enum Color {
    RED = 0x1,
    GREEN = 0x2,
    BLUE = 0x4,
    YELLOW = RED | GREEN,
    MAGENTA = RED | BLUE,
    CYAN = GREEN | BLUE,
    WHITE = RED | GREEN | BLUE
};

struct ColorAttributes {
    enum Color primary : 3;
    enum Color secondary : 3;
    unsigned int brightness : 4;
    unsigned int alpha : 8;
};

union DataConverter {
    struct PackedData packed;
    struct ColorAttributes color;
    unsigned int raw_data;
};

void print_binary(unsigned int num, int bits) {
    for (int i = bits - 1; i >= 0; i--) {
        printf("%d", (num >> i) & 1);
    }
}

void print_packed_data(struct PackedData data) {
    printf("PackedData:\n");
    printf("  flag1: %u\n", data.flag1);
    printf("  flag2: %u\n", data.flag2);
    printf("  count: %u\n", data.count);
    printf("  type: %u\n", data.type);
    printf("  mode: %u\n", data.mode);
    printf("  reserved: %u\n", data.reserved);
    
    printf("Binary representation: ");
    print_binary(*(unsigned int*)&data, 32);
    printf("\n");
}

void print_color_attributes(struct ColorAttributes attr) {
    printf("ColorAttributes:\n");
    printf("  primary: 0x%X\n", attr.primary);
    printf("  secondary: 0x%X\n", attr.secondary);
    printf("  brightness: %u\n", attr.brightness);
    printf("  alpha: %u\n", attr.alpha);
    
    printf("Binary representation: ");
    print_binary(*(unsigned int*)&attr, 32);
    printf("\n");
}

int main() {
    union DataConverter converter;
    
    // Test PackedData
    converter.packed.flag1 = 1;
    converter.packed.flag2 = 0;
    converter.packed.count = 63;
    converter.packed.type = 10;
    converter.packed.mode = 7;
    converter.packed.reserved = 0xFFFF;
    
    printf("Testing PackedData:\n");
    print_packed_data(converter.packed);
    
    // Test ColorAttributes
    converter.raw_data = 0;  // Reset
    converter.color.primary = RED;
    converter.color.secondary = BLUE;
    converter.color.brightness = 15;
    converter.color.alpha = 255;
    
    printf("\nTesting ColorAttributes:\n");
    print_color_attributes(converter.color);
    
    // Test color combinations
    printf("\nColor combinations:\n");
    printf("YELLOW (RED | GREEN): 0x%X\n", YELLOW);
    printf("MAGENTA (RED | BLUE): 0x%X\n", MAGENTA);
    printf("CYAN (GREEN | BLUE): 0x%X\n", CYAN);
    printf("WHITE (RED | GREEN | BLUE): 0x%X\n", WHITE);
    
    return 0;
}
