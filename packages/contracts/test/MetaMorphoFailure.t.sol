// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Tests how the vault behaves when MetaMorpho reverts or reports a
///         different share price. Uses vm.mockCall to simulate failure
///         modes without needing an actual Morpho market crash.
contract MetaMorphoFailureTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        super.setUp();
        bytes4[] memory s = new bytes4[](1);
        s[0] = bytes4(0xdeadbeef);
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT, LIFI_DIAMOND, s);
    }

    function test_deposit_reverts_when_metamorpho_paused() public {
        uint256 amount = 1_000 * 1e6;
        fundUsdc(alice, amount);

        // Simulate MetaMorpho deposit always reverting with "paused"
        vm.mockCallRevert(
            METAMORPHO_VAULT,
            abi.encodeWithSignature("deposit(uint256,address)", amount, address(vault)),
            "paused"
        );

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        vm.expectRevert(); // bubbles up from MetaMorpho
        vault.deposit(amount, alice);
        vm.stopPrank();
    }

    function test_totalAssets_reflects_share_price_drop() public {
        uint256 amount = 10_000 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        vault.deposit(amount, alice);
        vm.stopPrank();

        uint256 before = vault.totalAssets();

        // Simulate MetaMorpho reporting 10% lower total assets
        uint256 currentShares = IERC20(METAMORPHO_VAULT).balanceOf(address(vault));
        vm.mockCall(
            METAMORPHO_VAULT,
            abi.encodeWithSignature("convertToAssets(uint256)", currentShares),
            abi.encode(before * 90 / 100)
        );

        uint256 dropped = vault.totalAssets();
        assertEq(dropped, before * 90 / 100, "vault must honestly reflect underlying drop");
    }
}
