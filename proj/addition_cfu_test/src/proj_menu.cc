/*
 * Copyright 2021 The CFU-Playground Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "proj_menu.h"

#include <stdio.h>

#include "cfu.h"
#include "menu.h"

namespace {

// Template Fn
void do_hello_world(void) { puts("Hello, World!!!\n"); }

// Test template instruction
void do_exercise_cfu_op0(void) {
    puts("Running test on cfu\n");
    int8_t vals[] = {-127, -127, -127, -127};
    uint8_t filters[] = {2, 2, 2, 2};

    puts("Zeroing stuff\n");
    int32_t res = cfu_op0(1, 0, 0);
    // puts("\r\nExercise CFU Op0 aka ADD\r\n");
    int32_t software_res = 0;
    int32_t fails = 0;

    for (int8_t i1 = -127; i1 <= -126; i1++) {
        for (int8_t i2 = -127; i2 <= -126; i2++) {
            for (int8_t i3 = -127; i3 <= -126; i3++) {
                for (int8_t i4 = -127; i4 <= -126; i4++) {
                    for (int8_t f1 = -127; f1 <= -126; f1++) {
                        for (int8_t f2 = -127; f2 <= -126; f2++) {
                            for (int8_t f3 = -127; f3 <= -126; f3++) {
                                for (int8_t f4 = -127; f4 <= -126; f4++) {
                                    vals[0] = i1;
                                    vals[1] = i2;
                                    vals[2] = i3;
                                    vals[3] = i4;

                                    filters[0] = f1;
                                    filters[1] = f2;
                                    filters[2] = f3;
                                    filters[3] = f4;

                                    res = cfu_op0(0, vals, filters);
                                    software_res +=
                                        (i1 + 128) * f1 + (i2 + 128) * f2 +
                                        (i3 + 128) * f3 + (i4 + 128) * f4;
                                    printf("Result after filter sum = %li\n",
                                           res);
                                    printf("Software result after filter sum = "
                                           "%li\n",
                                           software_res);
                                    if (res != software_res)
                                        fails++;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    printf("Fails = %li\n", fails);
}

struct Menu MENU = {
    "Project Menu",
    "project",
    {
        MENU_ITEM('0', "exercise cfu op0", do_exercise_cfu_op0),
        MENU_ITEM('h', "say Hello", do_hello_world),
        MENU_END,
    },
};
}; // anonymous namespace

extern "C" void do_proj_menu() { menu_run(&MENU); }
