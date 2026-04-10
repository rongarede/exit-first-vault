// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseForkTest} from "./utils/BaseForkTest.sol";
import {VaultHandler} from "./utils/VaultHandler.sol";
import {ExitFirstVault} from "../src/ExitFirstVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Foundry invariant tests for ExitFirstVault.
///
///         Unlike fuzz tests (single call, single user), invariant tests
///         execute RANDOM SEQUENCES of actions (deposit, redeem, transfer)
///         across multiple users, then check that system-wide properties
///         still hold after EVERY step.
///
///         Configuration in foundry.toml:
///           [invariant] runs = 64, depth = 32
///         means: 64 independent runs, each with 32 random action steps.
///         Total: 64 × 32 = 2048 random state transitions checked.
contract InvariantVaultTest is BaseForkTest {
    ExitFirstVault internal vault;
    VaultHandler internal handler;

    address[] internal actors;

    function setUp() public override {
        super.setUp();
        vault = new ExitFirstVault(IERC20(USDC), METAMORPHO_VAULT);

        // Create 5 actors for the handler to pick from
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));
        actors.push(makeAddr("actor4"));

        handler = new VaultHandler(vault, actors);

        // Tell Foundry: only call functions on the handler, not on vault
        // directly. This ensures all interactions go through realistic
        // user flows (deposit with approve, redeem with balance check, etc.)
        targetContract(address(handler));
    }

    // --- Invariant 1: vault 不持有 USDC ---
    //
    // USDC 进入 vault 后立刻被转入 MetaMorpho（_deposit override）。
    // 任意操作序列后 vault 的 USDC 余额必须为 0。
    // 如果不为 0，说明 _deposit 或 _withdraw 有状态泄漏。

    function invariant_vault_holds_no_usdc() public view {
        assertEq(
            IERC20(USDC).balanceOf(address(vault)),
            0,
            "INVARIANT VIOLATED: vault holds residual USDC"
        );
    }

    // --- Invariant 2: totalSupply == 0 ⇒ totalAssets == 0 ---
    //
    // 如果所有 shares 都被赎回（totalSupply 归零），那么 vault 在
    // MetaMorpho 里不应该还有资产。允许 ≤ 10 wei 的 rounding dust。
    // 违反说明赎回逻辑有资产遗漏。

    function invariant_empty_vault_has_no_assets() public view {
        if (vault.totalSupply() == 0) {
            assertLe(
                vault.totalAssets(),
                10, // rounding dust tolerance
                "INVARIANT VIOLATED: totalSupply==0 but totalAssets>dust"
            );
        }
    }

    // --- Invariant 3: shares 守恒 ---
    //
    // sum(balanceOf(all actors)) == totalSupply
    // Transfer 只搬运 shares，不创造也不销毁。如果等式不成立，
    // 说明 mint/burn/transfer 有 accounting bug。

    function invariant_shares_conservation() public view {
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < actors.length; i++) {
            sumBalances += vault.balanceOf(actors[i]);
        }
        assertEq(
            sumBalances,
            vault.totalSupply(),
            "INVARIANT VIOLATED: sum(balanceOf) != totalSupply"
        );
    }

    // --- Invariant 4: totalAssets ≤ ghost_totalDeposited ---
    //
    // vault 报告的总资产不可能超过历史上所有存入金额之和。
    // MetaMorpho 可能产生收益使 totalAssets 略高于 deposited-redeemed，
    // 但绝不能超过 totalDeposited（没有外部注入的情况下）。
    // 这里用宽松上界 deposited 而非 deposited-redeemed，避免收益
    // 导致的误判。

    function invariant_totalAssets_bounded_by_deposits() public view {
        uint256 deposited = handler.ghost_totalDeposited();
        if (deposited == 0) return; // skip before first deposit
        assertLe(
            vault.totalAssets(),
            deposited + 100, // 100 wei tolerance for yield accrual in fork
            "INVARIANT VIOLATED: totalAssets exceeds total deposited"
        );
    }

    // --- Post-run summary ---

    function invariant_callSummary() public {
        emit log_named_uint("deposit calls", handler.ghost_depositCalls());
        emit log_named_uint("redeem calls",  handler.ghost_redeemCalls());
        emit log_named_uint("transfer calls", handler.ghost_transferCalls());
        emit log_named_uint("ghost_totalDeposited", handler.ghost_totalDeposited());
        emit log_named_uint("ghost_totalRedeemed",  handler.ghost_totalRedeemed());
    }
}
