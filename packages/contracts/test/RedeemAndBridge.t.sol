// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {ExitRouter} from "../src/ExitRouter.sol";
import {LifiFixture} from "./utils/LifiFixture.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RedeemAndBridgeTest is BaseForkTest {
    ExitFirstVault internal vault;
    ExitRouter internal router;

    function setUp() public override {
        // Use latest fork for LI.FI fixture freshness
        string memory rpc = vm.envOr("BASE_RPC", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc);
        METAMORPHO_VAULT = vm.envOr("METAMORPHO_VAULT", STEAKHOUSE_PRIME_USDC);

        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT);
        router = new ExitRouter(
            address(vault),
            LIFI_DIAMOND,
            allowedLifiSelectors()
        );
    }

    function test_rejects_empty_calldata() public {
        uint256 amount = 1_000 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        // Approve router to spend vault shares
        IERC20(address(vault)).approve(address(router), shares);

        vm.expectRevert(ExitRouter.EmptyCallData.selector);
        router.redeemAndBridge(shares, 0, alice, "");
        vm.stopPrank();
    }

    function test_rejects_disallowed_selector() public {
        uint256 amount = 1_000 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        IERC20(address(vault)).approve(address(router), shares);

        bytes memory badCall = abi.encodePacked(bytes4(0xaabbccdd), uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(ExitRouter.DisallowedSelector.selector, bytes4(0xaabbccdd))
        );
        router.redeemAndBridge(shares, 0, alice, badCall);
        vm.stopPrank();
    }

    /// @notice D-class happy path through ExitRouter → vault.redeem → LI.FI.
    function test_happy_path_base_to_arbitrum() public {
        LifiFixture.Fixture memory fix = LifiFixture.baseToArbUsdc1();
        uint256 fixtureAmount = fix.fromAmount;
        uint256 depositAmount = fixtureAmount * 110 / 100; // buffer for rounding

        fundUsdc(alice, depositAmount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        // Approve router to spend vault shares
        IERC20(address(vault)).approve(address(router), shares);

        uint256 aliceUsdcBefore = IERC20(USDC).balanceOf(alice);

        router.redeemAndBridge(
            shares,
            fixtureAmount,
            alice,
            fix.data
        );
        vm.stopPrank();

        // Post-conditions
        assertEq(vault.balanceOf(alice), 0, "alice vault shares should be zero");
        assertEq(
            IERC20(USDC).allowance(address(router), LIFI_DIAMOND),
            0,
            "no residual allowance on router"
        );

        uint256 dustReturned = IERC20(USDC).balanceOf(alice) - aliceUsdcBefore;
        emit log_named_uint("dust returned to alice", dustReturned);
        assertGt(dustReturned, 0, "expected buffer dust to flow back");
    }

    /// @notice Vault standard redeem still works independently of router.
    function test_standard_redeem_works_without_router() public {
        uint256 amount = 100 * 1e6;
        fundUsdc(alice, amount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        uint256 redeemed = vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertGt(redeemed, 0, "standard redeem must return assets");
        assertEq(vault.balanceOf(alice), 0, "shares should be zero after redeem");
    }
}
