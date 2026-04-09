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
        bytes4[] memory s = new bytes4[](1);
        s[0] = bytes4(0xdeadbeef);
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT, LIFI_DIAMOND, s);
    }

    function test_first_depositor_cannot_inflate_share_price() public {
        // Attacker: deposits 1 wei, then sends a huge donation directly to vault
        uint256 donation = 1_000_000 * 1e6; // 1M USDC donation

        fundUsdc(alice, 1 + donation);
        fundUsdc(bob, 1_000 * 1e6); // bob deposits 1000 USDC after

        // Alice deposits 1 wei
        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), 1);
        vault.deposit(1, alice);

        // Alice donates directly to vault (bypassing ERC4626 accounting)
        IERC20(USDC).transfer(address(vault), donation);
        vm.stopPrank();

        // Bob deposits 1000 USDC — should still receive a sensible number of shares
        vm.startPrank(bob);
        IERC20(USDC).approve(address(vault), 1_000 * 1e6);
        uint256 bobShares = vault.deposit(1_000 * 1e6, bob);
        vm.stopPrank();

        // Bob must receive > 0 shares and must be able to redeem ~his deposit back
        assertGt(bobShares, 0, "bob received zero shares: inflation attack succeeded");

        // Bob's redeemable value should be close to what he deposited
        uint256 bobRedeemable = vault.previewRedeem(bobShares);
        assertGe(
            bobRedeemable + (1_000 * 1e6 / 100),
            1_000 * 1e6,
            "bob lost >1% of deposit to donation-based inflation"
        );
    }
}
