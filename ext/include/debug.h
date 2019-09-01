#ifndef __DEBUG__
#define __DEBUG__

#define puts_length(name, array) printf("%s: %d\n", name, (int)RARRAY_LEN(array));

// #ifndef printf_array
//   #define printf_array( array, len ) \
//     printf("Array has %d elements: ", len); \
//     for (int i; i <= len; i++) { printf(" %d", array[i]); } \
//     printf("\n");
// #endif

#endif