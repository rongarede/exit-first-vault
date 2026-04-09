// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {LifiFixture} from "./utils/LifiFixture.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RedeemAndBridgeTest is BaseForkTest {
    ExitFirstVault internal vault;

    function setUp() public override {
        // Override BaseForkTest setUp to fork at LATEST block (not pinned).
        // LI.FI fixtures embed quote timestamps that go stale if the fork
        // block drifts behind by more than a few minutes. Happy-path test
        // needs a fresh fork; other tests can stay on pinned block.
        string memory rpc = vm.envOr("BASE_RPC", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc);
        METAMORPHO_VAULT = vm.envOr("METAMORPHO_VAULT", STEAKHOUSE_PRIME_USDC);

        vault = new ExitFirstVault(
            IERC20(USDC),
            METAMORPHO_VAULT,
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

    /// @notice D-class happy path: full round-trip through LI.FI Diamond.
    ///         Uses the smallest fixture (1 USDC) to keep the test fast.
    ///
    ///         Day 0 finding: LI.FI does not validate sender, so we deploy
    ///         the vault normally — no CREATE2 gymnastics required.
    ///
    ///         Sizing note: MetaMorpho rounds down on withdraw, so depositing
    ///         EXACTLY the fixture amount can leave the vault 1 wei short of
    ///         what the Diamond expects to pull. We deposit a small buffer
    ///         (+10%) and let the cleanup path refund the dust to Alice.
    function test_happy_path_base_to_arbitrum() public {
        LifiFixture.Fixture memory fix = LifiFixture.baseToArbUsdc1();
        uint256 fixtureAmount = fix.fromAmount;          // 1_000_000 = 1 USDC
        uint256 depositAmount = fixtureAmount * 110 / 100; // 1.1 USDC buffer

        fundUsdc(alice, depositAmount);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        uint256 aliceUsdcBefore = IERC20(USDC).balanceOf(alice);

        vault.redeemAndBridge(
            shares,
            fixtureAmount,  // slippage guard — require at least fixture amount out
            alice,
            fix.data
        );
        vm.stopPrank();

        // Post-conditions
        assertEq(vault.balanceOf(alice), 0, "alice shares should be zero");
        assertEq(
            IERC20(USDC).balanceOf(address(vault)),
            0,
            "vault should hold no residual USDC"
        );
        assertEq(
            IERC20(USDC).allowance(address(vault), LIFI_DIAMOND),
            0,
            "no residual allowance"
        );

        // Dust returned to Alice = deposited buffer minus what Diamond pulled.
        // Should be ≈ 0.1 USDC (depositAmount - fixtureAmount) minus rounding.
        uint256 dustReturned = IERC20(USDC).balanceOf(alice) - aliceUsdcBefore;
        emit log_named_uint("dust returned to alice", dustReturned);
        assertGt(dustReturned, 0, "expected buffer dust to flow back");
    }
}
