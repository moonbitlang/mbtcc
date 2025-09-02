
#include "test.h"

int partition(int arr[], int low, int high) {
    int pivot = arr[high];
    int i = (low - 1);
    for (int j = low; j < high; j++) {
        if (arr[j] < pivot) {
            i++;
            int temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }
    int temp = arr[i + 1];
    arr[i + 1] = arr[high];
    arr[high] = temp;
    return (i + 1);
}

void quick_sort(int arr[], int low, int high) {
    if (low < high) {
        int pivot = partition(arr, low, high);
        quick_sort(arr, low, pivot - 1);
        quick_sort(arr, pivot + 1, high);
    }
}

int main() {
  int arr[6] = { 5, 2, 6, 1, 4, 3 };
  quick_sort(arr, 0, 5);
  for (int i = 0; i < 6; i++) {
    printf("%d ", arr[i]);
  }
  printf("\n");
  return 0;
}
