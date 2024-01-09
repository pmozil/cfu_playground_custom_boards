#!/usr/bin/env python3
# Copyright 2021 The CFU-Playground Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import importlib
import pkgutil
from typing import Callable

from board_specific_workflows import parse_workflow_args, workflow_factory
from custom_boards import targets as custom_targets
from litex.soc.integration import soc
from litex_boards import targets


def get_soc_constructor_litex(target: str) -> Callable[..., soc.LiteXSoC]:
    """Returns the constructor for the target SoC from litex-boards module."""
    boards = {m.name for m in pkgutil.walk_packages(targets.__path__)}
    if target not in boards:
        s = ", ".join(sorted(boards))
        raise ValueError(f'Could not find "{target}" in supported boards: {s}')
    module = importlib.import_module(f"litex_boards.targets.{target}")
    return module.BaseSoC


def get_soc_constructor_custom(target: str) -> Callable[..., soc.LiteXSoC]:
    """Returns the constructor for the target SoC from python/custom_boards directory module."""
    boards = {m.name for m in pkgutil.walk_packages(custom_targets.__path__)}
    if target not in boards:
        s = ", ".join(sorted(boards))
        raise ValueError(f'Could not find "{target}" in supported boards: {s}')

    module = importlib.import_module(f"custom_boards.targets.{target}")
    return module.BaseSoC


def get_soc_constructor(target: str) -> Callable[..., soc.LiteXSoC]:
    """Returns the constructor for the target SoC."""
    try:
        return get_soc_constructor_litex(target)
    except ValueError:
        return get_soc_constructor_custom(target)


def main():
    parser = argparse.ArgumentParser(
        "Determine purpose (load software or hardware).", add_help=False
    )
    parser.add_argument(
        "--software-load",
        action="store_true",
        help="Perform pre-lxterm loading procedures.",
    )
    parser.add_argument("--software-path", help="Path to software to load")
    purpose, _ = parser.parse_known_args()

    args = parse_workflow_args()
    assert not (args.with_ethernet and args.with_etherbone)
    workflow = workflow_factory(args.target)(
        args, get_soc_constructor(args.target)
    )

    # Determine if call to code was for loading software or hardware/bios.
    if purpose.software_load == True:
        workflow.software_load(purpose.software_path)
    else:
        workflow.run()


if __name__ == "__main__":
    main()
