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

    function testFuzz_convertToShares_roundtrip(uint256 assets) public view {
        assets = bound(assets, 1, 1e18);
        uint256 shares = vault.convertToShares(assets);
        uint256 backAssets = vault.convertToAssets(shares);
        assertLe(backAssets, assets, "roundtrip must not inflate");
        assertGe(backAssets + 2, assets, "roundtrip rounding bounded by 2 wei");
    }

    function testFuzz_deposit_then_redeem_loses_at_most_dust(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000 * 1e6); // 1 USDC to 1M USDC
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        uint256 redeemed = vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertLe(redeemed, amount, "redeem must not exceed deposit");
        assertGe(redeemed + 10, amount, "dust bound: <= 10 wei loss per round-trip");
    }

    function test_totalAssets_tracks_metamorpho() public {
        uint256 amount = 10_000 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        vault.deposit(amount, alice);
        vm.stopPrank();

        uint256 reported = vault.totalAssets();
        assertGe(reported, amount - 10, "totalAssets must approximately match deposit");
        assertLe(reported, amount + 10, "totalAssets must not inflate");
    }
}
