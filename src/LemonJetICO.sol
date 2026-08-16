// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract LemonJetICO is Ownable, Pausable, ReentrancyGuard {

    uint256 private constant LJT_UNIT = 1e18;

    IERC20 private immutable ljt;
    IERC20 private immutable usdc;

    address public treasury;
    uint256 public price;

    event LjtPurchased(address indexed buyer, uint256 usdcAmount, uint256 ljtAmount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event LjtWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroPrice();

    constructor(address ljt_, address usdc_, address treasury_, uint256 price_) Ownable(msg.sender) {
        if (ljt_ == address(0) || usdc_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (price_ == 0) {
            revert ZeroPrice();
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

        usdc.transferFrom(msg.sender, treasury, usdcAmount);
        ljt.transfer(msg.sender, ljtAmount);

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

    function withdrawLjt(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        ljt.transfer(to, amount);
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
}
