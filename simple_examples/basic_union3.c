#include "test.h"

// 测试 Union 中包含 Struct
struct Point {
    int x;
    int y;
};

union Geometry {
    struct Point p;
    long long raw; // 假设 long long 足够大覆盖 struct Point
};

int main() {
    union Geometry geo;
    
    geo.p.x = 10;
    geo.p.y = 20;

    printf("Point: (%d, %d)\n", geo.p.x, geo.p.y);
    printf("Raw representation: %lld\n", geo.raw);

    // 修改 raw 可能会影响 struct
    geo.raw = 0;
    printf("After clearing raw, Point: (%d, %d)\n", geo.p.x, geo.p.y);

    return 0;
}

