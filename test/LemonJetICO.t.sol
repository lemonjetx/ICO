// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {LemonJetICO} from "../src/LemonJetICO.sol";

contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LemonJetICOTest is Test {
    LemonJetICO public ico;
    MockERC20 public ljt;
    MockERC20 public usdc;

    address public owner = makeAddr("owner");
    address public treasury = makeAddr("treasury");
    address public buyer = makeAddr("buyer");
    address public other = makeAddr("other");

    uint256 public constant PRICE = 100_000;
    uint256 public constant LJT_UNIT = 1e18;

    function setUp() public {
        ljt = new MockERC20("Lemon Jet", "LJT", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.prank(owner);
        ico = new LemonJetICO(address(ljt), address(usdc), treasury, PRICE);

        ljt.mint(address(ico), 1_000_000 * LJT_UNIT);
        usdc.mint(buyer, 1_000_000e6);
    }

    function _buy(address account, uint256 usdcAmount) internal {
        vm.startPrank(account);
        usdc.approve(address(ico), usdcAmount);
        ico.buy(usdcAmount);
        vm.stopPrank();
    }

    function test_BuyExact() public {
        uint256 usdcAmount = 1e6;
        uint256 expectedLjt = 10 * LJT_UNIT;

        _buy(buyer, usdcAmount);

        assertEq(ljt.balanceOf(buyer), expectedLjt);
        assertEq(usdc.balanceOf(treasury), usdcAmount);
        assertEq(usdc.balanceOf(address(ico)), 0);
        assertEq(usdc.balanceOf(buyer), 1_000_000e6 - usdcAmount);
        assertEq(ico.ljtAvailable(), 1_000_000 * LJT_UNIT - expectedLjt);
    }

    function test_BuyFloorsLjt() public {
        uint256 oddPrice = 3;
        vm.prank(owner);
        LemonJetICO oddIco = new LemonJetICO(address(ljt), address(usdc), treasury, oddPrice);
        ljt.mint(address(oddIco), 10 * LJT_UNIT);

        uint256 usdcAmount = 5;
        uint256 expectedLjt = 5 * LJT_UNIT / oddPrice;

        vm.startPrank(buyer);
        usdc.approve(address(oddIco), usdcAmount);
        oddIco.buy(usdcAmount);
        vm.stopPrank();

        assertEq(expectedLjt, 1_666_666_666_666_666_666);
        assertEq(ljt.balanceOf(buyer), expectedLjt);
        assertEq(usdc.balanceOf(treasury), usdcAmount);
        assertEq(usdc.balanceOf(buyer), 1_000_000e6 - usdcAmount);
    }

    function test_RevertBuyZeroAmount() public {
        vm.prank(buyer);
        vm.expectRevert(LemonJetICO.ZeroAmount.selector);
        ico.buy(0);
    }

    function test_BuyFractionalLjt() public {
        _buy(buyer, PRICE - 1);
        assertEq(ljt.balanceOf(buyer), (PRICE - 1) * LJT_UNIT / PRICE);
        assertEq(usdc.balanceOf(treasury), PRICE - 1);
    }

    function test_RevertBuyZeroLjtOut() public {
        uint256 hugePrice = LJT_UNIT + 1;
        vm.prank(owner);
        LemonJetICO expensive = new LemonJetICO(address(ljt), address(usdc), treasury, hugePrice);
        ljt.mint(address(expensive), LJT_UNIT);

        vm.startPrank(buyer);
        usdc.approve(address(expensive), 1);
        vm.expectRevert(LemonJetICO.ZeroAmount.selector);
        expensive.buy(1);
        vm.stopPrank();
    }

    function test_RevertBuyInsufficientLjt() public {
        uint256 inventory = 5 * LJT_UNIT;
        LemonJetICO smallIco;
        vm.prank(owner);
        smallIco = new LemonJetICO(address(ljt), address(usdc), treasury, PRICE);
        ljt.mint(address(smallIco), inventory);

        uint256 usdcAmount = 1e6;
        uint256 requested = 10 * LJT_UNIT;

        vm.startPrank(buyer);
        usdc.approve(address(smallIco), usdcAmount);
        vm.expectRevert(abi.encodeWithSelector(LemonJetICO.InsufficientLjt.selector, inventory, requested));
        smallIco.buy(usdcAmount);
        vm.stopPrank();
    }

    function test_PauseBlocksBuy() public {
        vm.prank(owner);
        ico.pause();

        vm.startPrank(buyer);
        usdc.approve(address(ico), 1e6);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        ico.buy(1e6);
        vm.stopPrank();
    }

    function test_UnpauseAllowsBuy() public {
        vm.prank(owner);
        ico.pause();
        vm.prank(owner);
        ico.unpause();

        _buy(buyer, 1e6);
        assertEq(ljt.balanceOf(buyer), 10 * LJT_UNIT);
    }

    function test_SetPrice() public {
        uint256 newPrice = 200_000;
        vm.prank(owner);
        ico.setPrice(newPrice);
        assertEq(ico.price(), newPrice);

        _buy(buyer, 1e6);
        assertEq(ljt.balanceOf(buyer), 5 * LJT_UNIT);
        assertEq(usdc.balanceOf(treasury), 1e6);
    }

    function test_RevertSetPriceZero() public {
        vm.prank(owner);
        vm.expectRevert(LemonJetICO.ZeroPrice.selector);
        ico.setPrice(0);
    }

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(owner);
        ico.setTreasury(newTreasury);
        assertEq(ico.treasury(), newTreasury);

        _buy(buyer, 1e6);
        assertEq(usdc.balanceOf(newTreasury), 1e6);
        assertEq(usdc.balanceOf(treasury), 0);
    }

    function test_RevertSetTreasuryZero() public {
        vm.prank(owner);
        vm.expectRevert(LemonJetICO.ZeroAddress.selector);
        ico.setTreasury(address(0));
    }

    function test_WithdrawLjt() public {
        uint256 amount = 100 * LJT_UNIT;
        vm.prank(owner);
        ico.withdrawLjt(other, amount);
        assertEq(ljt.balanceOf(other), amount);
        assertEq(ico.ljtAvailable(), 1_000_000 * LJT_UNIT - amount);
    }

    function test_RevertWithdrawLjtZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(LemonJetICO.ZeroAddress.selector);
        ico.withdrawLjt(address(0), 1);
    }

    function test_RevertWithdrawLjtZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(LemonJetICO.ZeroAmount.selector);
        ico.withdrawLjt(other, 0);
    }

    function test_OnlyOwnerGuards() public {
        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        ico.setPrice(1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        ico.setTreasury(buyer);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        ico.withdrawLjt(buyer, 1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        ico.pause();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        ico.unpause();
        vm.stopPrank();
    }

    function test_RevertConstructorZeroAddress() public {
        vm.expectRevert(LemonJetICO.ZeroAddress.selector);
        new LemonJetICO(address(0), address(usdc), treasury, PRICE);
        vm.expectRevert(LemonJetICO.ZeroAddress.selector);
        new LemonJetICO(address(ljt), address(0), treasury, PRICE);
        vm.expectRevert(LemonJetICO.ZeroAddress.selector);
        new LemonJetICO(address(ljt), address(usdc), address(0), PRICE);
    }

    function test_RevertConstructorZeroPrice() public {
        vm.expectRevert(LemonJetICO.ZeroPrice.selector);
        new LemonJetICO(address(ljt), address(usdc), treasury, 0);
    }

    function test_LjtForUsdc() public view {
        assertEq(ico.LJT_UNIT(), LJT_UNIT);
        assertEq(ico.USDC_UNIT(), 1e6);
        assertEq(ico.LJT_DECIMALS(), 18);
        assertEq(ico.USDC_DECIMALS(), 6);
        assertEq(ico.ljtForUsdc(PRICE), LJT_UNIT);
        assertEq(ico.ljtForUsdc(1e6), 10 * LJT_UNIT);
    }

    function test_RevertConstructorInvalidDecimals() public {
        MockERC20 badLjt = new MockERC20("Bad LJT", "BLJT", 6);
        MockERC20 badUsdc = new MockERC20("Bad USDC", "BUSDC", 18);
        vm.expectRevert(LemonJetICO.InvalidDecimals.selector);
        new LemonJetICO(address(badLjt), address(usdc), treasury, PRICE);
        vm.expectRevert(LemonJetICO.InvalidDecimals.selector);
        new LemonJetICO(address(ljt), address(badUsdc), treasury, PRICE);
    }

    function testFuzz_BuyConservation(uint256 usdcAmount) public {
        usdcAmount = bound(usdcAmount, PRICE, 100_000e6);
        uint256 ljtAmount = ico.ljtForUsdc(usdcAmount);

        assertEq(ljtAmount, usdcAmount * LJT_UNIT / PRICE);

        uint256 buyerUsdcBefore = usdc.balanceOf(buyer);
        uint256 buyerLjtBefore = ljt.balanceOf(buyer);
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 inventoryBefore = ico.ljtAvailable();

        if (ljtAmount > inventoryBefore) {
            vm.startPrank(buyer);
            usdc.approve(address(ico), usdcAmount);
            vm.expectRevert(abi.encodeWithSelector(LemonJetICO.InsufficientLjt.selector, inventoryBefore, ljtAmount));
            ico.buy(usdcAmount);
            vm.stopPrank();
            return;
        }

        _buy(buyer, usdcAmount);

        assertEq(ljt.balanceOf(buyer), buyerLjtBefore + ljtAmount);
        assertEq(usdc.balanceOf(buyer), buyerUsdcBefore - usdcAmount);
        assertEq(usdc.balanceOf(treasury), treasuryBefore + usdcAmount);
        assertEq(usdc.balanceOf(address(ico)), 0);
        assertEq(ico.ljtAvailable(), inventoryBefore - ljtAmount);
    }
}
