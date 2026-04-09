// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RedeemAndBridgeTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        super.setUp();
        bytes4[] memory selectors = new bytes4[](1);
        // Dummy selector. Real selectors get wired in Task 8 from Day 0 probe.
        selectors[0] = bytes4(0x12345678);
        vault = new ExitFirstVault(
            IERC20(USDC),
            METAMORPHO_VAULT,
            LIFI_DIAMOND,
            selectors
        );
    }

    function test_rejects_empty_calldata() public {
        uint256 amount = 1_000 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        vm.expectRevert(ExitFirstVault.EmptyCallData.selector);
        vault.redeemAndBridge(shares, 0, alice, "");
        vm.stopPrank();
    }

    function test_rejects_disallowed_selector() public {
        uint256 amount = 1_000 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        // 0xaabbccdd is not in the whitelist and does not collide with any
        // real LI.FI Diamond selector (verified against all-selectors.txt
        // from Day 0 probe).
        bytes memory badCall = abi.encodePacked(bytes4(0xaabbccdd), uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(ExitFirstVault.DisallowedSelector.selector, bytes4(0xaabbccdd))
        );
        vault.redeemAndBridge(shares, 0, alice, badCall);
        vm.stopPrank();
    }
}
