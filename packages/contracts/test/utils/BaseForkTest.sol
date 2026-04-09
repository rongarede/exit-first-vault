// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// @notice Base mainnet fork test harness.
///
///         Addresses verified on 2026-04-09 via Day 0 probe
///         (see `probe/day0-results.md`):
///         - USDC on Base: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
///         - LI.FI Diamond: 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE
///         - MetaMorpho vault: Steakhouse Prime USDC
///           0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2 (chosen for highest
///           Base USDC TVL at ~$468M, deepest redeem liquidity)
///
///         Fork is pinned to block 44_468_000 so tests are deterministic.
///         This is ≈15 minutes before the Day 0 probe run and all three
///         contracts are confirmed live at this block.
abstract contract BaseForkTest is Test {
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant LIFI_DIAMOND = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address internal constant STEAKHOUSE_PRIME_USDC = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;

    address internal METAMORPHO_VAULT;

    uint256 internal constant FORK_BLOCK = 44_468_000;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public virtual {
        string memory rpc = vm.envOr("BASE_RPC", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc, FORK_BLOCK);

        // Allow env override for swapping curators at test time without
        // editing source.
        METAMORPHO_VAULT = vm.envOr("METAMORPHO_VAULT", STEAKHOUSE_PRIME_USDC);
    }

    function fundUsdc(address to, uint256 amount) internal {
        deal(USDC, to, amount);
    }
}
