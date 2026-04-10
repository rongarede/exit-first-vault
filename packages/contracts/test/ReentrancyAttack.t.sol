// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {ExitRouter} from "../src/ExitRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Verifies the Router's `nonReentrant` modifier catches re-entry.
contract ReentrancyAttackTest is BaseForkTest {
    ExitFirstVault internal vault;
    ExitRouter internal router;

    function setUp() public override {
        super.setUp();
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT);

        bytes4[] memory s = new bytes4[](1);
        s[0] = ReentrantAttacker.attack.selector;
        router = new ExitRouter(address(vault), LIFI_DIAMOND, s);

        // Replace LIFI_DIAMOND with attacker bytecode
        ReentrantAttacker attacker = new ReentrantAttacker(address(router));
        vm.etch(LIFI_DIAMOND, address(attacker).code);
    }

    function test_reentrant_redeemAndBridge_reverts() public {
        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        IERC20(address(vault)).approve(address(router), shares);

        bytes memory malicious = abi.encodeWithSelector(
            ReentrantAttacker.attack.selector,
            shares
        );

        bytes memory expectedInner = abi.encodeWithSignature("ReentrancyGuardReentrantCall()");
        vm.expectRevert(
            abi.encodeWithSelector(ExitRouter.LifiCallFailed.selector, expectedInner)
        );
        router.redeemAndBridge(shares, 0, alice, malicious);
        vm.stopPrank();
    }
}

contract ReentrantAttacker {
    ExitRouter public immutable ROUTER;

    constructor(address router_) {
        ROUTER = ExitRouter(router_);
    }

    function attack(uint256 shares) external {
        bytes memory inner = abi.encodeWithSelector(this.attack.selector, shares);
        ROUTER.redeemAndBridge(shares, 0, address(this), inner);
    }
}
