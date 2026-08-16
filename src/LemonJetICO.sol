// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract LemonJetICO is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant LJT_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;
    uint256 public constant LJT_UNIT = 1e18;
    uint256 public constant USDC_UNIT = 1e6;

    IERC20 public immutable ljt;
    IERC20 public immutable usdc;

    address public treasury;
    uint256 public price;

    event LjtPurchased(address indexed buyer, uint256 usdcAmount, uint256 ljtAmount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event LjtWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroPrice();
    error InsufficientLjt(uint256 available, uint256 requested);
    error InvalidDecimals();

    constructor(address ljt_, address usdc_, address treasury_, uint256 price_) Ownable(msg.sender) {
        if (ljt_ == address(0) || usdc_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (price_ == 0) {
            revert ZeroPrice();
        }
        if (IERC20Metadata(ljt_).decimals() != LJT_DECIMALS) {
            revert InvalidDecimals();
        }
        if (IERC20Metadata(usdc_).decimals() != USDC_DECIMALS) {
            revert InvalidDecimals();
        }

        ljt = IERC20(ljt_);
        usdc = IERC20(usdc_);
        treasury = treasury_;
        price = price_;
    }

    function buy(uint256 usdcAmount) external nonReentrant whenNotPaused {
        if (usdcAmount == 0) {
            revert ZeroAmount();
        }

        uint256 ljtAmount = ljtForUsdc(usdcAmount);
        if (ljtAmount == 0) {
            revert ZeroAmount();
        }
        uint256 available = ljtAvailable();
        if (ljtAmount > available) {
            revert InsufficientLjt(available, ljtAmount);
        }

        usdc.safeTransferFrom(msg.sender, treasury, usdcAmount);
        ljt.safeTransfer(msg.sender, ljtAmount);

        emit LjtPurchased(msg.sender, usdcAmount, ljtAmount);
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) {
            revert ZeroPrice();
        }
        uint256 oldPrice = price;
        price = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function withdrawLjt(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        uint256 available = ljtAvailable();
        if (amount > available) {
            revert InsufficientLjt(available, amount);
        }
        ljt.safeTransfer(to, amount);
        emit LjtWithdrawn(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function ljtForUsdc(uint256 usdcAmount) public view returns (uint256) {
        return Math.mulDiv(usdcAmount, LJT_UNIT, price);
    }

    function ljtAvailable() public view returns (uint256) {
        return ljt.balanceOf(address(this));
    }
}
