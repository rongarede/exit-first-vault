// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ExitFirstVault} from "../../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Handler contract for Foundry invariant tests. Foundry calls random
///         functions on this handler with random args. Each function simulates
///         a realistic user action (deposit, redeem, transfer). The handler
///         tracks ghost variables so invariant assertions can compare on-chain
///         state against expected values.
contract VaultHandler is Test {
    ExitFirstVault public vault;
    address public usdc;

    // Actor pool — Foundry picks random callers from this set
    address[] public actors;

    // Ghost variables — track expected state off-chain
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalRedeemed;
    uint256 public ghost_depositCalls;
    uint256 public ghost_redeemCalls;
    uint256 public ghost_transferCalls;

    constructor(ExitFirstVault vault_, address[] memory actors_) {
        vault = vault_;
        usdc = vault.asset();
        actors = actors_;
    }

    // --- Bounded helpers ---

    function _pickActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    // --- Actions ---

    /// @notice Deposit a random amount of USDC into the vault.
    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = _pickActor(actorSeed);
        amount = bound(amount, 1e6, 100_000 * 1e6); // 1 to 100k USDC

        deal(usdc, actor, amount);

        vm.startPrank(actor);
        IERC20(usdc).approve(address(vault), amount);
        vault.deposit(amount, actor);
        vm.stopPrank();

        ghost_totalDeposited += amount;
        ghost_depositCalls++;
    }

    /// @notice Redeem a random fraction of an actor's shares.
    function redeem(uint256 actorSeed, uint256 fraction) external {
        address actor = _pickActor(actorSeed);
        uint256 shares = vault.balanceOf(actor);
        if (shares == 0) return; // skip if actor has nothing

        // Redeem between 1% and 100% of shares
        fraction = bound(fraction, 1, 100);
        uint256 toRedeem = shares * fraction / 100;
        if (toRedeem == 0) return;

        vm.startPrank(actor);
        uint256 assets = vault.redeem(toRedeem, actor, actor);
        vm.stopPrank();

        ghost_totalRedeemed += assets;
        ghost_redeemCalls++;
    }

    /// @notice Transfer vault shares between two random actors.
    function transfer(uint256 fromSeed, uint256 toSeed, uint256 fraction) external {
        address from = _pickActor(fromSeed);
        address to = _pickActor(toSeed);
        if (from == to) return;

        uint256 shares = vault.balanceOf(from);
        if (shares == 0) return;

        fraction = bound(fraction, 1, 100);
        uint256 toTransfer = shares * fraction / 100;
        if (toTransfer == 0) return;

        vm.prank(from);
        vault.transfer(to, toTransfer);

        ghost_transferCalls++;
    }
}
