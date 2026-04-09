// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Verifies the `nonReentrant` modifier catches a re-entry attempt
///         delivered through the LI.FI Diamond call in `redeemAndBridge`.
///
///         Strategy: `vm.etch` over LIFI_DIAMOND with attacker bytecode so
///         that when the vault calls `LIFI_DIAMOND.call(lifiCallData)`, the
///         attacker's `attack()` runs and tries to re-enter the vault.
contract ReentrancyAttackTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        super.setUp();
        bytes4[] memory s = new bytes4[](1);
        s[0] = ReentrantAttacker.attack.selector;
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT, LIFI_DIAMOND, s);

        ReentrantAttacker attacker = new ReentrantAttacker(address(vault));
        vm.etch(LIFI_DIAMOND, address(attacker).code);
    }

    function test_reentrant_redeemAndBridge_reverts() public {
        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        // Craft calldata that matches the attack() selector. Must include the
        // 4-byte selector as the first 4 bytes.
        bytes memory malicious = abi.encodeWithSelector(
            ReentrantAttacker.attack.selector,
            shares
        );

        // The inner re-entry trips OZ's ReentrancyGuard
        // (ReentrancyGuardReentrantCall = 0x3ee5aeb5). The outer call bubbles
        // that up wrapped in LifiCallFailed(returnData).
        bytes memory expectedInner = abi.encodeWithSignature("ReentrancyGuardReentrantCall()");
        vm.expectRevert(
            abi.encodeWithSelector(ExitFirstVault.LifiCallFailed.selector, expectedInner)
        );
        vault.redeemAndBridge(shares, 0, alice, malicious);
        vm.stopPrank();
    }
}

contract ReentrantAttacker {
    ExitFirstVault public immutable VAULT;

    constructor(address vault) {
        VAULT = ExitFirstVault(vault);
    }

    /// @notice Called from inside redeemAndBridge's LI.FI call; tries to
    ///         re-enter. Must hit the nonReentrant guard.
    function attack(uint256 shares) external {
        bytes memory inner = abi.encodeWithSelector(this.attack.selector, shares);
        VAULT.redeemAndBridge(shares, 0, address(this), inner);
    }
}
