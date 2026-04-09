// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AccountingTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        super.setUp();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(0xdeadbeef); // dummy; real selectors wired in Task 8
        vault = new ExitFirstVault(
            IERC20(USDC),
            METAMORPHO_VAULT,
            LIFI_DIAMOND,
            selectors
        );
    }

    function test_asset_is_usdc() public view {
        assertEq(vault.asset(), USDC);
    }

    function test_deposit_mints_shares_and_forwards_to_metamorpho() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        vm.stopPrank();

        assertGt(shares, 0, "shares should be minted");
        assertEq(vault.balanceOf(alice), shares);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0, "vault should hold no USDC");
        // MetaMorpho shares should be non-zero
        assertGt(
            IERC20(METAMORPHO_VAULT).balanceOf(address(vault)),
            0,
            "vault should hold MetaMorpho shares"
        );
    }
}
