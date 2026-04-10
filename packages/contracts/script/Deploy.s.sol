// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {ExitRouter} from "../src/ExitRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Deploys ExitFirstVault + ExitRouter to Base mainnet.
///
///         Required env vars:
///           BASE_RPC          — JSON-RPC endpoint for Base
///           DEPLOYER_PK       — private key (0x-prefixed) for broadcast
///           METAMORPHO_VAULT  — chosen MetaMorpho USDC vault address
///                               (default: Steakhouse Prime USDC)
contract Deploy is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant LIFI_DIAMOND = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    address constant STEAKHOUSE_PRIME_USDC = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;

    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        address metaMorpho = vm.envOr("METAMORPHO_VAULT", STEAKHOUSE_PRIME_USDC);

        bytes4[] memory selectors = _whitelistedSelectors();

        vm.startBroadcast(pk);

        ExitFirstVault vault = new ExitFirstVault(
            IERC20(USDC),
            metaMorpho
        );

        ExitRouter router = new ExitRouter(
            address(vault),
            LIFI_DIAMOND,
            selectors
        );

        vm.stopBroadcast();

        console2.log("ExitFirstVault deployed at:", address(vault));
        console2.log("ExitRouter deployed at:    ", address(router));
        console2.log("Underlying asset (USDC):   ", USDC);
        console2.log("MetaMorpho vault:          ", metaMorpho);
        console2.log("LI.FI Diamond:             ", LIFI_DIAMOND);
        console2.log("Whitelisted selector count:", selectors.length);
        console2.log("Router owner:              ", vm.addr(pk));
    }

    function _whitelistedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](13);
        s[0]  = 0xe796cd98;
        s[1]  = 0xf97136af;
        s[2]  = 0xa1f1ce43;
        s[3]  = 0x1794958f;
        s[4]  = 0x14d53077;
        s[5]  = 0xa6010a66;
        s[6]  = 0xfb214c2f;
        s[7]  = 0x5fd9ae2e;
        s[8]  = 0x2c57e884;
        s[9]  = 0x736eac0b;
        s[10] = 0x4666fc80;
        s[11] = 0x733214a3;
        s[12] = 0xaf7060fd;
        return s;
    }
}
