# Simple-IOS-Developer-Kits

### Tutorial

- InOut:
```C
#include "InOut.h"

int main(void) {
    char name[64];
    
    in("your name? ", name, sizeof name); // input
    
    out("Hello %s!\n", name);             // print (output)
    return 0;
}
```

- Canvas:
```C
#include "Canvas.h"
//NOTE:
#include <algorithm> ❌
#include <vector>    ❌


void setup(void) {
    size(100, 100);  // resolution
}

void draw(void) {
    background(225);

    fill(100);
    box(10, 20, 30, 40);

    box(50, 60, 20, 20) {
        fill(255, 0, 0);
    }

    fill(0, 128, 255);
    circle(70, 70, 10);

    fill(0);
    line(0, 0, 99, 99);
}
```

- Delay:
```C
#include "Delay.h"

void worker(void *arg) {
    out("3\n"); delay_s(1);
    out("2\n"); delay_s(1);
    out("1\n"); delay_s(1);
    out("Go!\n");
}
```

