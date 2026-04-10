// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {ExitRouter} from "../src/ExitRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fuzz arbitrary bytes as `lifiCallData` through the Router.
contract CallDataGriefingTest is BaseForkTest {
    ExitFirstVault internal vault;
    ExitRouter internal router;

    function setUp() public override {
        super.setUp();
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT);
        router = new ExitRouter(
            address(vault),
            LIFI_DIAMOND,
            allowedLifiSelectors()
        );
    }

    function testFuzz_random_calldata_cannot_succeed_silently(bytes calldata data) public {
        vm.assume(data.length >= 4);
        bytes4 sel = bytes4(data[:4]);

        bytes4[] memory whitelist = allowedLifiSelectors();
        for (uint256 i = 0; i < whitelist.length; i++) {
            vm.assume(sel != whitelist[i]);
        }

        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        IERC20(address(vault)).approve(address(router), shares);

        vm.expectRevert(
            abi.encodeWithSelector(ExitRouter.DisallowedSelector.selector, sel)
        );
        router.redeemAndBridge(shares, 0, alice, data);
        vm.stopPrank();
    }

    function test_whitelisted_but_broken_calldata_leaves_no_residue() public {
        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        IERC20(address(vault)).approve(address(router), shares);

        bytes4 sel = allowedLifiSelectors()[3]; // Across primary
        bytes memory junk = abi.encodePacked(sel, bytes("garbage-garbage-garbage-data"));

        vm.expectRevert();
        router.redeemAndBridge(shares, 0, alice, junk);

        // State intact after revert
        assertEq(vault.balanceOf(alice), shares, "shares must be restored");
        assertEq(
            IERC20(USDC).allowance(address(router), LIFI_DIAMOND),
            0,
            "no residual allowance"
        );
        vm.stopPrank();
    }
}
