#
# This file is part of LiteX.
#
# Copyright (c) 2018 Dolu1990 <charles.papon.90@gmail.com>
# Copyright (c) 2018-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2018-2019 Sean Cross <sean@xobs.io>
# Copyright (c) 2019 Tim 'mithro' Ansell <me@mith.ro>
# Copyright (c) 2019 David Shah <dave@ds0.me>
# Copyright (c) 2019 Antmicro <www.antmicro.com>
# Copyright (c) 2019 Kurt Kiefer <kekiefer@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause

import os

from litex.soc.cores.cpu.vexriscv.core import CPU_VARIANTS, VexRiscv
from litex.soc.interconnect import wishbone
from migen import *

# VexRiscv


class VexRiscvCFURAM(VexRiscv):
    def __init__(self, platform, variant="standard", with_timer=False):
        self.platform = platform
        self.variant = variant
        self.human_name = CPU_VARIANTS.get(variant, "VexRiscv")
        self.external_variant = None
        self.reset = Signal()
        self.interrupt = Signal(32)
        self.ibus = ibus = wishbone.Interface()
        self.dbus = dbus = wishbone.Interface()
        self.cfu_mem = cfu_mem = wishbone.Interface()
        self.periph_buses = [
            ibus,
            dbus,
            cfu_mem,
        ]  # Peripheral buses (Connected to main SoC's bus).

        self.memory_buses = (
            []
        )  # Memory buses (Connected directly to LiteDRAM).

        # # #

        # CPU Instance.
        self.cpu_params = dict(
            i_clk=ClockSignal("sys"),
            i_reset=ResetSignal("sys") | self.reset,
            i_externalInterruptArray=self.interrupt,
            i_timerInterrupt=0,
            i_softwareInterrupt=0,
            o_iBusWishbone_ADR=ibus.adr,
            o_iBusWishbone_DAT_MOSI=ibus.dat_w,
            o_iBusWishbone_SEL=ibus.sel,
            o_iBusWishbone_CYC=ibus.cyc,
            o_iBusWishbone_STB=ibus.stb,
            o_iBusWishbone_WE=ibus.we,
            o_iBusWishbone_CTI=ibus.cti,
            o_iBusWishbone_BTE=ibus.bte,
            i_iBusWishbone_DAT_MISO=ibus.dat_r,
            i_iBusWishbone_ACK=ibus.ack,
            i_iBusWishbone_ERR=ibus.err,
            o_dBusWishbone_ADR=dbus.adr,
            o_dBusWishbone_DAT_MOSI=dbus.dat_w,
            o_dBusWishbone_SEL=dbus.sel,
            o_dBusWishbone_CYC=dbus.cyc,
            o_dBusWishbone_STB=dbus.stb,
            o_dBusWishbone_WE=dbus.we,
            o_dBusWishbone_CTI=dbus.cti,
            o_dBusWishbone_BTE=dbus.bte,
            i_dBusWishbone_DAT_MISO=dbus.dat_r,
            i_dBusWishbone_ACK=dbus.ack,
            i_dBusWishbone_ERR=dbus.err,
        )

        # Add Timer (Optional).
        if with_timer:
            self.add_timer()

        # Add Debug (Optional).
        if "debug" in variant:
            self.add_debug()

    def add_cfu(self, cfu_filename):
        # Check CFU presence.
        if not os.path.exists(cfu_filename):
            raise OSError(
                f"Unable to find VexRiscv CFU plugin {cfu_filename}."
            )

        # CFU:CPU Bus Layout.
        cfu_bus_layout = [
            (
                "cmd",
                [
                    ("valid", 1),
                    ("ready", 1),
                    (
                        "payload",
                        [
                            ("function_id", 10),
                            ("inputs_0", 32),
                            ("inputs_1", 32),
                        ],
                    ),
                ],
            ),
            (
                "rsp",
                [
                    ("valid", 1),
                    ("ready", 1),
                    (
                        "payload",
                        [
                            ("outputs_0", 32),
                        ],
                    ),
                ],
            ),
        ]

        # The CFU:CPU Bus.
        self.cfu_bus = cfu_bus = Record(cfu_bus_layout)

        # Connect CFU to the CFU:CPU bus.
        self.cfu_params = dict(
            i_cmd_valid=cfu_bus.cmd.valid,
            o_cmd_ready=cfu_bus.cmd.ready,
            i_cmd_payload_function_id=cfu_bus.cmd.payload.function_id,
            i_cmd_payload_inputs_0=cfu_bus.cmd.payload.inputs_0,
            i_cmd_payload_inputs_1=cfu_bus.cmd.payload.inputs_1,
            o_rsp_valid=cfu_bus.rsp.valid,
            i_rsp_ready=cfu_bus.rsp.ready,
            o_rsp_payload_outputs_0=cfu_bus.rsp.payload.outputs_0,
            i_clk=ClockSignal("sys"),
            i_reset=ResetSignal("sys"),
            # Wishbone mem interface
            o_cfu_ram_adr=self.cfu_mem.adr,
            o_cfu_ram_dat_mosi=self.cfu_mem.dat_w,
            o_cfu_ram_sel=self.cfu_mem.sel,
            o_cfu_ram_cyc=self.cfu_mem.cyc,
            o_cfu_ram_stb=self.cfu_mem.stb,
            o_cfu_ram_we=self.cfu_mem.we,
            o_cfu_ram_cti=self.cfu_mem.cti,
            o_cfu_ram_bte=self.cfu_mem.bte,
            i_cfu_ram_dat_miso=self.cfu_mem.dat_r,
            i_cfu_ram_ack=self.cfu_mem.ack,
            i_cfu_ram_err=self.cfu_mem.err,
        )
        self.platform.add_source(cfu_filename)

        # Connect CPU to the CFU:CPU bus.
        self.cpu_params.update(
            o_CfuPlugin_bus_cmd_valid=cfu_bus.cmd.valid,
            i_CfuPlugin_bus_cmd_ready=cfu_bus.cmd.ready,
            o_CfuPlugin_bus_cmd_payload_function_id=cfu_bus.cmd.payload.function_id,
            o_CfuPlugin_bus_cmd_payload_inputs_0=cfu_bus.cmd.payload.inputs_0,
            o_CfuPlugin_bus_cmd_payload_inputs_1=cfu_bus.cmd.payload.inputs_1,
            i_CfuPlugin_bus_rsp_valid=cfu_bus.rsp.valid,
            o_CfuPlugin_bus_rsp_ready=cfu_bus.rsp.ready,
            i_CfuPlugin_bus_rsp_payload_outputs_0=cfu_bus.rsp.payload.outputs_0,
        )
