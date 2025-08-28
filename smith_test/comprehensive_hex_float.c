int main() {
    // Test various hex float formats
    double d1 = 0x1.0p0;           // 1.0
    double d2 = 0x1.0p1;           // 2.0  
    double d3 = 0x1.8p0;           // 1.5
    double d4 = 0x1.921fb54442d18p+2;  // Pi * 2^2 ≈ 6.28
    double d5 = 0x1.0p-1;          // 0.5
    double d6 = 0x0.8p1;           // 0.5 * 2 = 1.0
    double d7 = 0xA.Bp2;           // (10 + 11/16) * 4 = 42.75
    double d8 = 0xFF.FFp-8;        // (255 + 255/256) / 256 ≈ 0.999
    
    return 0;
}