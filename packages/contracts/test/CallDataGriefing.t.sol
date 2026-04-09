// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fuzz arbitrary bytes as `lifiCallData`. Non-whitelisted selectors
///         must revert at the whitelist check. Whitelisted selectors with
///         broken arguments will revert inside the Diamond — the whole
///         transaction should revert with no residue.
contract CallDataGriefingTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        super.setUp();
        vault = new ExitFirstVault(
            IERC20(USDC),
            METAMORPHO_VAULT,
            LIFI_DIAMOND,
            allowedLifiSelectors()
        );
    }

    function testFuzz_random_calldata_cannot_succeed_silently(bytes calldata data) public {
        vm.assume(data.length >= 4);
        bytes4 sel = bytes4(data[:4]);

        // Exclude any selector that happens to collide with our whitelist —
        // those paths are covered by the happy-path and inner-revert tests.
        bytes4[] memory whitelist = allowedLifiSelectors();
        for (uint256 i = 0; i < whitelist.length; i++) {
            vm.assume(sel != whitelist[i]);
        }

        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        vm.expectRevert(
            abi.encodeWithSelector(ExitFirstVault.DisallowedSelector.selector, sel)
        );
        vault.redeemAndBridge(shares, 0, alice, data);
        vm.stopPrank();
    }

    function test_whitelisted_but_broken_calldata_leaves_no_residue() public {
        // A whitelisted selector + junk arguments: the whitelist check passes,
        // but the Diamond reverts when trying to decode. The whole
        // redeemAndBridge transaction must revert — shares stay in Alice's
        // hand and no allowance leaks out to the Diamond.
        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        bytes4 sel = allowedLifiSelectors()[3]; // 0x1794958f = Across primary
        bytes memory junk = abi.encodePacked(sel, bytes("garbage-garbage-garbage-data"));

        vm.expectRevert(); // Diamond will revert somewhere inside decoding
        vault.redeemAndBridge(shares, 0, alice, junk);

        // State must be intact after the revert
        assertEq(vault.balanceOf(alice), shares, "shares must be restored");
        assertEq(
            IERC20(USDC).allowance(address(vault), LIFI_DIAMOND),
            0,
            "no residual allowance after failed call"
        );
        assertEq(
            IERC20(USDC).balanceOf(address(vault)),
            0,
            "vault must not hold orphan USDC"
        );
        vm.stopPrank();
    }
}
