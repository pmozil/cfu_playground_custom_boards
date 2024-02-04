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
    puts("\r\nExercise CFU Op0 aka ADD\r\n");

    int8_t img_vals[] = {-128, -128, -128, -127};
    int8_t filter_vals[] = {1, 1, 1, 1};
    int32_t acc = 0;

    cfu_op0(1, 0, 0);
    cfu_op1(2, 1, 1);
    cfu_op2(3, 1, 1);
    cfu_op3(4, 4, 128);
    cfu_op4(5, 0, 0);
    cfu_op5(6, img_vals, filter_vals);
    cfu_op6(8, 0, 0);
    cfu_op7(7, 1, 0);
    cfu_op0(1, 0, 0);

    puts("Perform convolution\r\n");
    acc = cfu_op1(0, 0, 0);
    printf("result = %li\r\n", acc);
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
