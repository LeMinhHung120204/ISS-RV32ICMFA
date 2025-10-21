#include <iostream>
#include <cmath>

using namespace std;

  union newfloat{
    float f;
    int i;
  };

int main () {
// Input number
newfloat x;
cout << "Enter Number: ";
cin >> x.f;

// Pull out exponent and mantissa
int exponent = (x.i >> 23) & 0xFF;
int mantissa = (x.i & 0x7FFFFF) | ((exponent && exponent) << 23);

// Calculate new exponent
int new_exponent = (exponent >> 1) + 63 + (exponent & 1);


// Shift right (paper says shift left but shift left doesn't work?)
if (exponent & 1) {
    mantissa = mantissa  >> 1;
    cout << " Shifted right " << endl;
}

// Create an array with the bits of the mantissa
unsigned int D [48];
for (int i = 47; i >= 0; i--) {
  if (i >= 24) {
    D[i] = (mantissa >> (i-24)) & 1;
  } else {
    D[i] = 0;
  }
}


// == Perform square root ==
// Set q24 = 0, r24 = 0 and then iterate from k = 23 to 0
int q[25] = {0}; // 25 element array, indexing ends at 24
int r[25] = {0};

for (int k = 23; k >= 0; k--) {
    if (r[k+1] >= 0) {
        r[k] = ((r[k+1] << 2) | (D[2*k+1] << 1) | D[2*k] ) - (q[k+1] << 2 | 1 );
        } else {
        r[k] = ((r[k+1] << 2) | (D[2*k+1] << 1) | D[2*k] ) + (q[k+1] << 2 | 0x3 );
        } 

    if (r[k] >= 0) {
        q[k] = (q[k+1] << 1) | 1;
        } else {
        q[k] = q[k+1] << 1;
    }

    if (k == 0) {
        if (r[0] < 0) {
            r[0] = r[0] + (q[0] << 1) | 1;
        }
    }
}

// Create quotient from LSBs of q[]
int Q = 0;
for (int i = 0; i <= 23; i++) {
    Q = Q | ((q[i] & 1) << i);
}

// Option 1 Rounding
//if (r[0] > 0) // Works for 10, 1001, 1021, but not 1012
// Q = Q + 1;

// Option 2 Rounding (No rounding)
// Works for 1012, Doesn't work for 10, 1001, 1021

// Option 3 Rounding (Calculate the next 3 Quotient bits to get a guard round and sticky bit)

// Calculate correct result:
newfloat correct_result;
correct_result.f = sqrt(x.f);

// Form my result into a single number
newfloat myresult;
myresult.i = (new_exponent << 23) | (Q & 0x7FFFFF);

// Print results
cout << hex << "My result: " << myresult.i << endl;
cout << hex << "Correct:   " <<  correct_result.i << endl;
return 0;
}