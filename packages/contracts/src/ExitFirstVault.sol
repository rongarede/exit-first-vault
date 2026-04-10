// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626, IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title  ExitFirstVault
/// @notice Pure ERC-4626 wrapper over a MetaMorpho USDC vault.
/// @dev    Immutable: no owner, no upgrade, no pause, no fee.
///         Cross-chain exit is handled by the separate ExitRouter contract,
///         which can be upgraded independently without affecting user funds.
contract ExitFirstVault is ERC4626 {
    using SafeERC20 for IERC20;

    IERC4626 public immutable METAMORPHO;

    constructor(
        IERC20 asset_,
        address metaMorpho
    )
        ERC20("Exit-First USDC Vault", "efUSDC")
        ERC4626(asset_)
    {
        METAMORPHO = IERC4626(metaMorpho);
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
}
