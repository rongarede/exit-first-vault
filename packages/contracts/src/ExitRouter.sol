// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  ExitRouter
/// @notice Periphery contract that composes vault.redeem() + LI.FI bridge
///         into a single transaction. Replaceable: if LI.FI upgrades their
///         Diamond facets, deploy a new Router. User funds in the vault are
///         never at risk — standard ERC-4626 redeem always works.
/// @dev    Follows the Uniswap Pool/Router pattern: the vault (Pool) is
///         immutable, the Router is upgradeable by deploying a new one.
contract ExitRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC4626 public immutable VAULT;
    address public immutable LIFI_DIAMOND;

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

    event SelectorAdded(bytes4 selector);
    event SelectorRemoved(bytes4 selector);

    constructor(
        address vault,
        address lifiDiamond,
        bytes4[] memory allowedSelectors_
    ) Ownable(msg.sender) {
        VAULT = IERC4626(vault);
        LIFI_DIAMOND = lifiDiamond;
        for (uint256 i = 0; i < allowedSelectors_.length; i++) {
            _allowedSelectors.push(allowedSelectors_[i]);
        }
    }

    // --- Core entry ---

    /// @notice Redeem vault shares and atomically bridge resulting USDC via
    ///         LI.FI Diamond. Caller must have approved this Router to spend
    ///         their vault shares (ERC-20 approve on the vault token).
    /// @param  shares        Vault shares to redeem.
    /// @param  minAssetsOut  Minimum USDC expected (source-chain slippage guard).
    /// @param  receiver      Event-only field for indexers.
    /// @param  lifiCallData  Pre-constructed LI.FI Diamond calldata.
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

        // Transfer vault shares from caller to this contract
        IERC20(address(VAULT)).safeTransferFrom(msg.sender, address(this), shares);

        // Redeem shares → USDC lands in this contract
        address asset = VAULT.asset();
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        VAULT.redeem(shares, address(this), address(this));
        uint256 assetsOut = IERC20(asset).balanceOf(address(this)) - balanceBefore;

        if (assetsOut < minAssetsOut) revert InsufficientAssetsOut(assetsOut, minAssetsOut);

        // Approve LI.FI Diamond and invoke bridge facet
        IERC20(asset).forceApprove(LIFI_DIAMOND, assetsOut);
        (bool ok, bytes memory ret) = LIFI_DIAMOND.call(lifiCallData);
        if (!ok) revert LifiCallFailed(ret);

        // Cleanup: clear residual allowance, sweep dust back to caller
        IERC20(asset).forceApprove(LIFI_DIAMOND, 0);
        uint256 dust = IERC20(asset).balanceOf(address(this)) - balanceBefore;
        if (dust > 0) {
            IERC20(asset).safeTransfer(msg.sender, dust);
        }

        emit RedeemAndBridge(msg.sender, receiver, shares, assetsOut, dust, sel);
    }

    // --- Selector management (owner only) ---

    function addSelector(bytes4 sel) external onlyOwner {
        _allowedSelectors.push(sel);
        emit SelectorAdded(sel);
    }

    function removeSelector(bytes4 sel) external onlyOwner {
        uint256 len = _allowedSelectors.length;
        for (uint256 i = 0; i < len; i++) {
            if (_allowedSelectors[i] == sel) {
                _allowedSelectors[i] = _allowedSelectors[len - 1];
                _allowedSelectors.pop();
                emit SelectorRemoved(sel);
                return;
            }
        }
    }

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
