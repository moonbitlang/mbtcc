#include "test.h"

// 测试复杂的类型定义和函数指针
typedef int (*CompareFunc)(const void*, const void*);
typedef void (*PrintFunc)(const void*);

struct Person {
    char* name;
    int age;
};

struct Student {
    struct Person base;
    float gpa;
};

struct Employee {
    struct Person base;
    float salary;
};

int compare_int(const void* a, const void* b) {
    return (*(int*)a - *(int*)b);
}

int compare_person_age(const void* a, const void* b) {
    struct Person* p1 = (struct Person*)a;
    struct Person* p2 = (struct Person*)b;
    return p1->age - p2->age;
}

void print_int(const void* data) {
    printf("%d", *(int*)data);
}

void print_person(const void* data) {
    struct Person* p = (struct Person*)data;
    printf("Name: %s, Age: %d", p->name, p->age);
}

void print_student(const void* data) {
    struct Student* s = (struct Student*)data;
    printf("Name: %s, Age: %d, GPA: %.2f",
           s->base.name, s->base.age, s->gpa);
}

void print_employee(const void* data) {
    struct Employee* e = (struct Employee*)data;
    printf("Name: %s, Age: %d, Salary: %.2f",
           e->base.name, e->base.age, e->salary);
}

void print_array(void* array, int size, int elem_size, PrintFunc print) {
    char* ptr = (char*)array;
    for (int i = 0; i < size; i++) {
        if (i > 0) printf(", ");
        print((void*)ptr);
        ptr += elem_size;
    }
    printf("\n");
}

int main() {
    // Test with integers
    int numbers[] = {5, 2, 8, 1, 9};
    printf("Numbers: ");
    print_array(numbers, 5, sizeof(int), print_int);
    
    // Test with persons
    struct Person persons[] = {
        {"John", 25},
        {"Alice", 30},
        {"Bob", 20}
    };
    printf("Persons: ");
    print_array(persons, 3, sizeof(struct Person), print_person);
    
    // Test with students
    struct Student students[] = {
        {{"Tom", 22}, 3.8f},
        {{"Jerry", 21}, 3.9f}
    };
    printf("\nStudents: ");
    print_array(students, 2, sizeof(struct Student), print_student);
    
    // Test with employees
    struct Employee employees[] = {
        {{"Mike", 35}, 50000.0f},
        {{"Sarah", 28}, 45000.0f}
    };
    printf("\nEmployees: ");
    print_array(employees, 2, sizeof(struct Employee), print_employee);
    
    return 0;
}
