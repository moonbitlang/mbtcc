#include "test.h"

// 编辑距离实现
#define MIN3(a, b, c) ((a) < (b) ? ((a) < (c) ? (a) : (c)) : ((b) < (c) ? (b) : (c)))

void print_matrix(int dp[100][100], int m, int n,
                 const char* str1, const char* str2) {
    printf("    ");
    printf("  ");
    for (int j = 0; j < n; j++) {
        printf("%c ", str2[j]);
    }
    printf("\n");
    
    for (int i = 0; i <= m; i++) {
        if (i == 0) printf("  ");
        else printf("%c ", str1[i-1]);
        
        for (int j = 0; j <= n; j++) {
            printf("%d ", dp[i][j]);
        }
        printf("\n");
    }
}

void print_operations(const char* str1, const char* str2,
                     int dp[100][100], int m, int n) {
    int i = m, j = n;
    printf("\nRequired operations:\n");
    
    while (i > 0 || j > 0) {
        if (i > 0 && j > 0 && str1[i-1] == str2[j-1]) {
            printf("Match '%c'\n", str1[i-1]);
            i--;
            j--;
        }
        else if (j > 0 && (i == 0 || dp[i][j] == dp[i][j-1] + 1)) {
            printf("Insert '%c'\n", str2[j-1]);
            j--;
        }
        else if (i > 0 && (j == 0 || dp[i][j] == dp[i-1][j] + 1)) {
            printf("Delete '%c'\n", str1[i-1]);
            i--;
        }
        else {
            printf("Replace '%c' with '%c'\n", str1[i-1], str2[j-1]);
            i--;
            j--;
        }
    }
}

int edit_distance(const char* str1, const char* str2) {
    int m = strlen(str1);
    int n = strlen(str2);
    int dp[100][100];
    
    // Initialize first row and column
    for (int i = 0; i <= m; i++)
        dp[i][0] = i;
    for (int j = 0; j <= n; j++)
        dp[0][j] = j;
    
    // Fill dp table
    printf("Building DP table:\n");
    for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
            if (str1[i-1] == str2[j-1])
                dp[i][j] = dp[i-1][j-1];
            else
                dp[i][j] = 1 + MIN3(dp[i-1][j],      // Delete
                                   dp[i][j-1],      // Insert
                                   dp[i-1][j-1]);   // Replace
        }
        print_matrix(dp, m, n, str1, str2);
        printf("\n");
    }
    
    print_operations(str1, str2, dp, m, n);
    return dp[m][n];
}

// Test cases
void test_basic_edit_distance() {
    printf("Testing basic edit distance:\n");
    const char* str1 = "horse";
    const char* str2 = "ros";
    
    printf("String 1: %s\n", str1);
    printf("String 2: %s\n", str2);
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
}

void test_same_strings() {
    printf("Testing identical strings:\n");
    const char* str1 = "hello";
    const char* str2 = "hello";
    
    printf("String 1: %s\n", str1);
    printf("String 2: %s\n", str2);
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
}

void test_empty_string() {
    printf("Testing with empty string:\n");
    const char* str1 = "hello";
    const char* str2 = "";
    
    printf("String 1: %s\n", str1);
    printf("String 2: (empty)\n");
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
}

void test_single_operation() {
    printf("Testing single operation cases:\n");
    
    // Single insertion
    printf("Single insertion test:\n");
    const char* str1 = "cat";
    const char* str2 = "cats";
    printf("String 1: %s\n", str1);
    printf("String 2: %s\n", str2);
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
    
    // Single deletion
    printf("Single deletion test:\n");
    str1 = "cats";
    str2 = "cat";
    printf("String 1: %s\n", str1);
    printf("String 2: %s\n", str2);
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
    
    // Single replacement
    printf("Single replacement test:\n");
    str1 = "cat";
    str2 = "cut";
    printf("String 1: %s\n", str1);
    printf("String 2: %s\n", str2);
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
}

void test_completely_different() {
    printf("Testing completely different strings:\n");
    const char* str1 = "abc";
    const char* str2 = "xyz";
    
    printf("String 1: %s\n", str1);
    printf("String 2: %s\n", str2);
    printf("Edit distance: %d\n\n",
           edit_distance(str1, str2));
}

int main() {
    test_basic_edit_distance();
    test_same_strings();
    test_empty_string();
    test_single_operation();
    test_completely_different();
    
    return 0;
}
