// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626, IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  ExitFirstVault
/// @notice ERC-4626 wrapper over a MetaMorpho USDC vault with a one-signature
///         cross-chain exit entry (`redeemAndBridge`) that routes through the
///         LI.FI Diamond.
/// @dev    Immutable: no owner, no upgrade, no pause, no fee. See
///         `docs/superpowers/specs/2026-04-09-exit-first-vault-design.md`.
contract ExitFirstVault is ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC4626 public immutable METAMORPHO;
    address public immutable LIFI_DIAMOND;

    // Allowed LI.FI Diamond function selectors. Set once in constructor.
    // See spec §5.2 "Selector whitelist".
    bytes4[] private _allowedSelectors;

    error DisallowedSelector(bytes4 selector);
    error InsufficientAssetsOut(uint256 got, uint256 wanted);
    error LifiCallFailed(bytes returnData);
    error EmptyCallData();

    event RedeemAndBridge(
        address indexed caller,
        address indexed receiver,
        uint256 shares,
        uint256 assetsOut,
        uint256 dustReturned,
        bytes4 selector
    );

    constructor(
        IERC20 asset_,
        address metaMorpho,
        address lifiDiamond,
        bytes4[] memory allowedSelectors_
    )
        ERC20("Exit-First USDC Vault", "efUSDC")
        ERC4626(asset_)
    {
        METAMORPHO = IERC4626(metaMorpho);
        LIFI_DIAMOND = lifiDiamond;
        for (uint256 i = 0; i < allowedSelectors_.length; i++) {
            _allowedSelectors.push(allowedSelectors_[i]);
        }
    }

    // --- ERC4626 overrides: route assets to/from MetaMorpho ---

    /// @dev Total assets under management = our MetaMorpho share balance
    ///      converted to underlying USDC at the current rate.
    function totalAssets() public view override returns (uint256) {
        return METAMORPHO.convertToAssets(METAMORPHO.balanceOf(address(this)));
    }

    /// @dev Intercept _deposit to forward USDC into MetaMorpho after caller
    ///      transfers it into this vault.
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        super._deposit(caller, receiver, assets, shares);
        // USDC is now in this vault; forward to MetaMorpho.
        IERC20(asset()).forceApprove(address(METAMORPHO), assets);
        METAMORPHO.deposit(assets, address(this));
    }

    /// @dev Intercept _withdraw to pull USDC out of MetaMorpho before paying
    ///      out to receiver.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        METAMORPHO.withdraw(assets, address(this), address(this));
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // --- Differentiating entry: redeemAndBridge ---

    /// @notice Redeem vault shares and atomically bridge resulting USDC via
    ///         LI.FI Diamond to an arbitrary chain/asset. Source-chain only;
    ///         destination settlement is async.
    /// @param  shares        Shares to burn.
    /// @param  minAssetsOut  Minimum USDC expected from MetaMorpho redemption
    ///                       (source-chain slippage guard).
    /// @param  receiver      Event-only field for indexers; LI.FI's real
    ///                       receiver is encoded inside `lifiCallData`. The
    ///                       frontend is responsible for keeping the two
    ///                       consistent.
    /// @param  lifiCallData  Pre-constructed LI.FI Diamond calldata
    ///                       (swapAndStartBridgeTokensVia* family). First 4
    ///                       bytes must be a whitelisted selector.
    function redeemAndBridge(
        uint256 shares,
        uint256 minAssetsOut,
        address receiver,
        bytes calldata lifiCallData
    ) external nonReentrant {
        // Checks
        if (lifiCallData.length < 4) revert EmptyCallData();
        bytes4 sel = bytes4(lifiCallData[:4]);
        if (!_isAllowedSelector(sel)) revert DisallowedSelector(sel);

        // Effects: burn shares, pull assets out of MetaMorpho
        uint256 assetsExpected = previewRedeem(shares);
        _burn(msg.sender, shares);

        uint256 balanceBefore = IERC20(asset()).balanceOf(address(this));
        METAMORPHO.withdraw(assetsExpected, address(this), address(this));
        uint256 assetsOut = IERC20(asset()).balanceOf(address(this)) - balanceBefore;

        if (assetsOut < minAssetsOut) revert InsufficientAssetsOut(assetsOut, minAssetsOut);

        // Interactions: approve LI.FI Diamond and invoke the bridge facet
        IERC20(asset()).forceApprove(LIFI_DIAMOND, assetsOut);
        (bool ok, bytes memory ret) = LIFI_DIAMOND.call(lifiCallData);
        if (!ok) revert LifiCallFailed(ret);

        // Cleanup (defense-in-depth; Day 0 probe found Across leaves no
        // residue, but other facets may differ). Cost: ~10k gas on happy path.
        IERC20(asset()).forceApprove(LIFI_DIAMOND, 0);
        uint256 dust = IERC20(asset()).balanceOf(address(this)) - balanceBefore;
        if (dust > 0) {
            IERC20(asset()).safeTransfer(msg.sender, dust);
        }

        emit RedeemAndBridge(msg.sender, receiver, shares, assetsOut, dust, sel);
    }

    // --- Selector whitelist helpers ---

    function allowedSelectors() external view returns (bytes4[] memory) {
        return _allowedSelectors;
    }

    function _isAllowedSelector(bytes4 sel) internal view returns (bool) {
        uint256 len = _allowedSelectors.length;
        for (uint256 i = 0; i < len; i++) {
            if (_allowedSelectors[i] == sel) return true;
        }
        return false;
    }
}
