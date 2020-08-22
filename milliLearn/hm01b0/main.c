#include <stdio.h>
#include "HM01B0_RAW8_QVGA_8bits_lsb_5fps.h"

int main()
{
    for (int i = 0; i < sizeof(sHM01B0InitScript) / sizeof(sHM01B0InitScript[0]); i++) {
        printf("0a4 1%02x 1%02x 1%02x 041\n",
               (sHM01B0InitScript[i].ui16Reg & 0xff00) >> 8,
               (sHM01B0InitScript[i].ui16Reg & 0x00ff) >> 0,
               (sHM01B0InitScript[i].ui8Val));
    }

    return 0;
}
