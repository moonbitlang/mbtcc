#include "test.h"

// 最长公共子序列实现
#define MAX_LEN 100

void print_lcs_table(int dp[MAX_LEN][MAX_LEN], int m, int n,
                    const char* X, const char* Y) {
    printf("LCS Table:\n");
    printf("    ");
    for (int j = 0; j < n; j++) {
        printf("%c ", Y[j]);
    }
    printf("\n");
    
    for (int i = 0; i <= m; i++) {
        if (i == 0) printf("  ");
        else printf("%c ", X[i-1]);
        
        for (int j = 0; j <= n; j++) {
            printf("%d ", dp[i][j]);
        }
        printf("\n");
    }
}

void print_lcs(int dp[MAX_LEN][MAX_LEN], const char* X, int i, int j,
               char* lcs, int index) {
    if (i == 0 || j == 0) {
        lcs[index] = '\0';
        printf("LCS: %s\n", lcs);
        return;
    }
    
    if (X[i-1] == X[j-1]) {
        lcs[index-1] = X[i-1];
        print_lcs(dp, X, i-1, j-1, lcs, index-1);
    }
    else if (dp[i-1][j] > dp[i][j-1]) {
        print_lcs(dp, X, i-1, j, lcs, index);
    }
    else {
        print_lcs(dp, X, i, j-1, lcs, index);
    }
}

int lcs_length(const char* X, const char* Y, int m, int n) {
    int dp[MAX_LEN][MAX_LEN];
    
    // Initialize table
    for (int i = 0; i <= m; i++) {
        for (int j = 0; j <= n; j++) {
            if (i == 0 || j == 0)
                dp[i][j] = 0;
            else if (X[i-1] == Y[j-1])
                dp[i][j] = dp[i-1][j-1] + 1;
            else
                dp[i][j] = dp[i-1][j] > dp[i][j-1] ?
                          dp[i-1][j] : dp[i][j-1];
        }
    }
    
    print_lcs_table(dp, m, n, X, Y);
    
    // Print one possible LCS
    char lcs[MAX_LEN];
    print_lcs(dp, X, m, n, lcs, dp[m][n]);
    
    return dp[m][n];
}

// Test cases
void test_basic_lcs() {
    printf("Testing basic LCS:\n");
    const char* X = "ABCDGH";
    const char* Y = "AEDFHR";
    int m = strlen(X);
    int n = strlen(Y);
    
    printf("String 1: %s\n", X);
    printf("String 2: %s\n", Y);
    printf("Length of LCS: %d\n\n",
           lcs_length(X, Y, m, n));
}

void test_same_strings() {
    printf("Testing identical strings:\n");
    const char* X = "ABCDEF";
    const char* Y = "ABCDEF";
    int m = strlen(X);
    int n = strlen(Y);
    
    printf("String 1: %s\n", X);
    printf("String 2: %s\n", Y);
    printf("Length of LCS: %d\n\n",
           lcs_length(X, Y, m, n));
}

void test_no_common() {
    printf("Testing strings with no common characters:\n");
    const char* X = "ABCDEF";
    const char* Y = "GHIJKL";
    int m = strlen(X);
    int n = strlen(Y);
    
    printf("String 1: %s\n", X);
    printf("String 2: %s\n", Y);
    printf("Length of LCS: %d\n\n",
           lcs_length(X, Y, m, n));
}

void test_subsequence() {
    printf("Testing subsequence:\n");
    const char* X = "ABCDEFGH";
    const char* Y = "ACE";
    int m = strlen(X);
    int n = strlen(Y);
    
    printf("String 1: %s\n", X);
    printf("String 2: %s\n", Y);
    printf("Length of LCS: %d\n\n",
           lcs_length(X, Y, m, n));
}

void test_edge_cases() {
    printf("Testing edge cases:\n");
    
    // Empty string
    printf("Empty string test:\n");
    const char* X = "";
    const char* Y = "ABC";
    int m = strlen(X);
    int n = strlen(Y);
    printf("String 1: (empty)\n");
    printf("String 2: %s\n", Y);
    printf("Length of LCS: %d\n\n",
           lcs_length(X, Y, m, n));
    
    // Single character
    printf("Single character test:\n");
    X = "A";
    Y = "A";
    m = strlen(X);
    n = strlen(Y);
    printf("String 1: %s\n", X);
    printf("String 2: %s\n", Y);
    printf("Length of LCS: %d\n\n",
           lcs_length(X, Y, m, n));
}

int main() {
    test_basic_lcs();
    test_same_strings();
    test_no_common();
    test_subsequence();
    test_edge_cases();
    
    return 0;
}
