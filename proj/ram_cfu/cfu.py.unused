import unittest

from amaranth import C, Module, Signal, signed
from amaranth_cfu import (InstructionBase, InstructionTestBase, all_words,
                          pack_vals, simple_cfu)


# Custom instruction inherits from the InstructionBase class.
class SimdMac(InstructionBase):
    def __init__(self, input_offset=128) -> None:
        self.cfu_ram_adr = Signal(30, name="cfu_ram_adr")
        self.cfu_ram_dat_mosi = Signal(32, name="cfu_ram_dat_mosi")
        self.cfu_ram_sel = Signal(4, name="cfu_ram_sel")
        self.cfu_ram_cyc = Signal(name="cfu_ram_cyc")
        self.cfu_ram_stb = Signal(name="cfu_ram_stb")
        self.cfu_ram_we = Signal(name="cfu_ram_we")
        self.cfu_ram_cti = Signal(3, name="cfu_ram_cti")
        self.cfu_ram_bte = Signal(2, name="cfu_ram_bte")
        self.cfu_ram_dat_miso = Signal(32, name="cfu_ram_dat_miso")
        self.cfu_ram_ack = Signal(name="cfu_ram_ack")
        self.cfu_ram_err = Signal(name="cfu_ram_err")


        super().__init__()

        self.input_offset = C(input_offset, signed(9))

    # `elab` method implements the logic of the instruction.
    def elab(self, m: Module) -> None:
        words = lambda s: all_words(s, 8)

        # SIMD multiply step:
        self.prods = [Signal(signed(16)) for _ in range(4)]
        for prod, w0, w1 in zip(self.prods, words(self.in0), words(self.in1)):
            m.d.comb += prod.eq(
                (w0.as_signed() + self.input_offset) * w1.as_signed()
            )

        m.d.sync += self.done.eq(0)
        # self.start signal high for one cycle when instruction started.
        with m.If(self.start):
            with m.If(self.funct7):
                m.d.sync += self.output.eq(0)
            with m.Else():
                # Accumulate step:
                m.d.sync += self.output.eq(self.output + sum(self.prods))
            # self.done signal indicates instruction is completed.
            m.d.sync += self.done.eq(1)


# Tests for the instruction inherit from InstructionTestBase class.
class SimdMacTest(InstructionTestBase):
    def create_dut(self):
        return SimdMac()

    def test(self):
        # self.verify method steps through expected inputs and outputs.
        self.verify(
            [
                (1, 0, 0, 0),  # reset
                (
                    0,
                    pack_vals(-128, 0, 0, 1),
                    pack_vals(111, 0, 0, 1),
                    129 * 1,
                ),
                (0, pack_vals(0, -128, 1, 0), pack_vals(0, 52, 1, 0), 129 * 2),
                (0, pack_vals(0, 1, 0, 0), pack_vals(0, 1, 0, 0), 129 * 3),
                (0, pack_vals(1, 0, 0, 0), pack_vals(1, 0, 0, 0), 129 * 4),
                (0, pack_vals(0, 0, 0, 0), pack_vals(0, 0, 0, 0), 129 * 4),
                (0, pack_vals(0, 0, 0, 0), pack_vals(-5, 0, 0, 0), 0xFFFFFF84),
                (1, 0, 0, 0),  # reset
                (
                    0,
                    pack_vals(-12, -128, -88, -128),
                    pack_vals(-1, -7, -16, 15),
                    0xFFFFFD0C,
                ),
                (1, 0, 0, 0),  # reset
                (
                    0,
                    pack_vals(127, 127, 127, 127),
                    pack_vals(127, 127, 127, 127),
                    129540,
                ),
                (1, 0, 0, 0),  # reset
                (
                    0,
                    pack_vals(127, 127, 127, 127),
                    pack_vals(-128, -128, -128, -128),
                    0xFFFE0200,
                ),
            ]
        )


# Expose make_cfu function for cfu_gen.py
def make_cfu():
    # Associate cfu_op0 with SimdMac.
    return simple_cfu({0: SimdMac()})


# Use `../../scripts/pyrun cfu.py` to run unit tests.
if __name__ == "__main__":
    unittest.main()
