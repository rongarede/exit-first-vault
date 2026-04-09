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

    /// @notice Returns the LI.FI Diamond bridge facet selectors that the
    ///         vault pins in its whitelist.
    ///
    ///         Source: Day 0 probe enumerated all 258 Diamond selectors via
    ///         `facets()` (see `probe/facets-raw.txt`), then selected three
    ///         bridge facets covering the dominant Base → L1/L2 USDC routes:
    ///
    ///         - Across facet 0xAd3f1634a917924cBb54A0F76e43ca035D2B6BCd
    ///           (observed live for Base → Arb/Op/Poly/BSC USDC)
    ///         - StargateV2 facet 0x6e378C84e657C57b2a8d183CFf30ee5CC8989b61
    ///           (observed live for Base → ETH USDC and WETH)
    ///         - CCTP (CircleBridge) facet
    ///           0x31a9b1835864706Af10103b31Ea2b79bdb995F5F (Circle-native
    ///           canonical USDC bridging — included for future-proofing in
    ///           case LI.FI starts routing here)
    ///
    ///         Admin / DiamondLoupe / Ownership selectors are deliberately
    ///         excluded — they would be harmless (Diamond gates them by
    ///         owner) but waste whitelist slots in the immutable vault.
    function allowedLifiSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](13);
        // Across facet (4 selectors)
        s[0]  = 0xe796cd98;
        s[1]  = 0xf97136af;
        s[2]  = 0xa1f1ce43;
        s[3]  = 0x1794958f; // observed: Base→Arb/Op/Poly/BSC USDC
        // StargateV2 facet (3 selectors)
        s[4]  = 0x14d53077;
        s[5]  = 0xa6010a66; // observed: Base→ETH USDC/WETH
        s[6]  = 0xfb214c2f;
        // CCTP (CircleBridge) facet (6 selectors)
        s[7]  = 0x5fd9ae2e;
        s[8]  = 0x2c57e884;
        s[9]  = 0x736eac0b;
        s[10] = 0x4666fc80;
        s[11] = 0x733214a3;
        s[12] = 0xaf7060fd;
        return s;
    }
}
