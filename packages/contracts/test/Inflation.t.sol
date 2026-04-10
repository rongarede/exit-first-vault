// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Verifies OZ 5.0 virtual shares defense against the first-depositor
///         inflation attack.
contract InflationTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        super.setUp();
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT);
    }

    function test_first_depositor_cannot_inflate_share_price() public {
        uint256 donation = 1_000_000 * 1e6;

        fundUsdc(alice, 1 + donation);
        fundUsdc(bob, 1_000 * 1e6);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), 1);
        vault.deposit(1, alice);
        IERC20(USDC).transfer(address(vault), donation);
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(USDC).approve(address(vault), 1_000 * 1e6);
        uint256 bobShares = vault.deposit(1_000 * 1e6, bob);
        vm.stopPrank();

        assertGt(bobShares, 0, "bob received zero shares: inflation attack succeeded");

        uint256 bobRedeemable = vault.previewRedeem(bobShares);
        assertGe(
            bobRedeemable + (1_000 * 1e6 / 100),
            1_000 * 1e6,
            "bob lost >1% of deposit to donation-based inflation"
        );
    }
}
