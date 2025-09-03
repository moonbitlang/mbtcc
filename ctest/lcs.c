#include "test.h"

#define MAX_LEN 20

// Helper function to find maximum of two integers
int max(int a, int b) {
    return (a > b) ? a : b;
}

// Function to find the length of Longest Common Subsequence
int lcs(const char* X, const char* Y, int m, int n) {
    int dp[MAX_LEN + 1][MAX_LEN + 1];

    // Build dp table in bottom-up manner
    for (int i = 0; i <= m; i++) {
        for (int j = 0; j <= n; j++) {
            if (i == 0 || j == 0)
                dp[i][j] = 0;
            else if (X[i-1] == Y[j-1])
                dp[i][j] = dp[i-1][j-1] + 1;
            else
                dp[i][j] = max(dp[i-1][j], dp[i][j-1]);
        }
    }

    return dp[m][n];
}

// Function to calculate string length (simple implementation)
int my_strlen(const char* s) {
    int len = 0;
    while (s[len] != '\0') {
        len++;
    }
    return len;
}

int main() {
    const char* S1 = "AGGTAB";
    const char* S2 = "GXTXAYB";

    int len1 = my_strlen(S1);
    int len2 = my_strlen(S2);

    printf("Length of LCS is %d\n", lcs(S1, S2, len1, len2)); // Expected: 4 (GTAB)

    const char* S3 = "ABCBDAB";
    const char* S4 = "BDCABA";

    int len3 = my_strlen(S3);
    int len4 = my_strlen(S4);

    printf("Length of LCS is %d\n", lcs(S3, S4, len3, len4)); // Expected: 4 (BCBA or BDAB)

    return 0;
}
