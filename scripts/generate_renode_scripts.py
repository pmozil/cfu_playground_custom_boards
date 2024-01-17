#!/usr/bin/env python3
# Copyright 2021 The CFU-Playground Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import json
import os
import re
import sys
from importlib import import_module
from shutil import copy

sys.path.append(
    (
        os.path.join(
            os.path.dirname(__file__),
            "..",
            "third_party",
            "python",
            "litex",
            "litex",
            "tools",
        )
    )
)

litex_renode = import_module("litex_json2renode")


def generate_resc(target, cfu_lib_filepath):
    result = (
        """
using sysbus
mach create \""""
        + target
        + """\"
machine LoadPlatformDescription $ORIGIN/"""
        + target
        + """.repl
machine StartGdbServer 10001
showAnalyzer sysbus.uart
showAnalyzer sysbus.uart Antmicro.Renode.Analyzers.LoggingUartAnalyzer
"""
    )
    if cfu_lib_filepath:
        result += (
            """
cpu.cfu0 SimulationFilePathLinux @"""
            + cfu_lib_filepath
            + """
"""
        )

    result += """
sysbus LoadELF $ORIGIN/../software.elf
"""
    return result


def generate_litex_renode_repl(conf_file, etherbone_peripherals, autoalign):
    with open(conf_file) as f:
        csr = json.load(f)

    result = litex_renode.generate_repl(csr, etherbone_peripherals, autoalign)

    return result


def generate_repl(target, path, cfu_lib_filepath, predefined=False):
    if predefined:
        result = 'using "' + str(path) + str(target) + '_predefined.repl"'
    else:
        result = 'using "' + str(path) + str(target) + '_generated.repl"'

    result += """

cpu:
    init:
        RegisterCustomCSR "BPM" 0xB04  User
        RegisterCustomCSR "BPM" 0xB05  User
        RegisterCustomCSR "BPM" 0xB06  User
        RegisterCustomCSR "BPM" 0xB07  User
        RegisterCustomCSR "BPM" 0xB08  User
        RegisterCustomCSR "BPM" 0xB09  User
        RegisterCustomCSR "BPM" 0xB0A  User
        RegisterCustomCSR "BPM" 0xB0B  User
        RegisterCustomCSR "BPM" 0xB0C  User
        RegisterCustomCSR "BPM" 0xB0D  User
        RegisterCustomCSR "BPM" 0xB0E  User
        RegisterCustomCSR "BPM" 0xB0F  User
        RegisterCustomCSR "BPM" 0xB10  User
        RegisterCustomCSR "BPM" 0xB11  User
        RegisterCustomCSR "BPM" 0xB12  User
        RegisterCustomCSR "BPM" 0xB13  User
        RegisterCustomCSR "BPM" 0xB14  User
        RegisterCustomCSR "BPM" 0xB15  User
"""
    if cfu_lib_filepath:
        result += """
cfu0: Verilated.CFUVerilatedPeripheral @ cpu 0
"""
    return result


def generate_robot(robot_template_path, target):
    with open(robot_template_path, "r") as f:
        file_content = f.read()
        file_content = file_content.replace("TARGET", target)

    return file_content


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "conf_file", help="JSON configuration generated by LiteX"
    )
    parser.add_argument("target", help="Target name")
    parser.add_argument("build_path", help="Output path for generated files")
    parser.add_argument(
        "--repl", action="store", help="Output platform definition file"
    )
    parser.add_argument(
        "--etherbone",
        action="append",
        dest="etherbone_peripherals",
        default=[],
        help="Peripheral to connect over etherbone bridge",
    )
    parser.add_argument(
        "--auto-align",
        action="append",
        dest="autoalign_memor_regions",
        default=[],
        help="List of memory regions to align automatically (necessary due to limitations in Renode)",
    )
    parser.add_argument(
        "--sw-only",
        action="store_true",
        help="Generate script without simulating hardware CFU",
    )
    args = parser.parse_args()

    return args


def main():
    args = parse_args()

    resc_filepath = args.build_path + args.target + ".resc"
    repl_filepath = args.build_path + args.target + ".repl"
    litex_renode_repl_filepath = (
        args.build_path + args.target + "_generated.repl"
    )
    robot_filepath = args.build_path + args.target + ".robot"

    proj_name = re.search("proj/(.*)/build", args.build_path)
    proj_name = proj_name.group(1)

    proj_path = os.path.abspath(os.path.join(args.build_path, "../.."))
    predefined_resc_path = os.path.join(
        proj_path, "renode", args.target + ".resc"
    )
    predefined_repl_path = os.path.join(
        proj_path, "renode", args.target + ".repl"
    )
    predefined_robot_path = os.path.join(
        proj_path, "renode", args.target + ".robot"
    )
    robot_template_path = os.path.join(proj_path, proj_name + ".robot")

    cfu_lib_filepath = os.path.join(args.build_path, "libVtop.so")
    if not os.path.isfile(cfu_lib_filepath) or args.sw_only:
        cfu_lib_filepath = None

    if os.path.isfile(predefined_resc_path):
        copy(predefined_resc_path, args.build_path)
    else:
        with open(resc_filepath, "w") as f:
            f.write(generate_resc(args.target, cfu_lib_filepath))

    etherbone_peripherals = litex_renode.check_etherbone_peripherals(
        args.etherbone_peripherals
    )

    # if there is a predefined Renode platform script for a target, copy it to build directory,
    # otherwise generate a new one with LiteX-Renode
    if os.path.isfile(predefined_repl_path):
        copy(
            predefined_repl_path,
            os.path.join(args.build_path, f"{args.target}_predefined.repl"),
        )

        with open(repl_filepath, "w") as f:
            f.write(
                generate_repl(
                    args.target,
                    args.build_path,
                    cfu_lib_filepath,
                    predefined=True,
                )
            )
    else:
        with open(litex_renode_repl_filepath, "w") as f:
            f.write(
                generate_litex_renode_repl(
                    args.conf_file,
                    etherbone_peripherals,
                    args.autoalign_memor_regions,
                )
            )

        with open(repl_filepath, "w") as f:
            f.write(
                generate_repl(args.target, args.build_path, cfu_lib_filepath)
            )

    if os.path.isfile(predefined_robot_path):
        copy(predefined_robot_path, args.build_path)
    elif os.path.isfile(robot_template_path):
        with open(robot_filepath, "w") as f:
            f.write(generate_robot(robot_template_path, args.target))
    else:
        print(
            "Warning: {} was not generated, could not find {}".format(
                proj_name + ".robot", robot_template_path
            )
        )


if __name__ == "__main__":
    main()
