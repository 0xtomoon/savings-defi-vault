//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interface/IAToken.sol";
import "./interface/IAavePool.sol";
import "./interface/IBalancerVault.sol";

contract TestBalancer is ReentrancyGuardUpgradeable {
	using SafeERC20 for IERC20;
  uint256 public MAX_INT = 2**256 - 1;

  IERC20 public DUSD;
  IERC20 public DAI;
  IERC20 public FLUID;
  IAToken public aArbDAI;
  IAavePool public aavePool;
	IBalancerVault public balancerVault;
  bytes32 public balancerPoolId;
  address public fluidTreasury;

  uint256[] public fluidTiers;
  uint256[] public feeTiers;

  mapping(address => uint256) public daiBalances;
  mapping(address => uint256) public scaledBalances;

	constructor(address _balancerVault) {
    balancerVault = IBalancerVault(_balancerVault);
  }

	function setBalancerVault(address _balancerVault) external {
		balancerVault = IBalancerVault(_balancerVault);
	}

  function balancerSwap(uint256 amount, address assetIn, address assetOut, address recipient, bytes32 poolId) internal returns (uint256) {
    IERC20(assetIn).safeApprove(address(balancerVault), amount);
    bytes memory userData = "";
    uint256 value = balancerVault.swap(
      IBalancerVault.SingleSwap(poolId, IBalancerVault.SwapKind.GIVEN_IN, assetIn, assetOut, amount, userData),
      IBalancerVault.FundManagement(address(this), true, payable(recipient), false),
      0,
      MAX_INT
    );
    return value;
  }

  function withdraw(address token, uint256 amount) public nonReentrant returns(uint256) {
    require(token == address(DUSD) || token == address(DAI), "Not allowed token deposited");

    uint256 amountInDai = token == address(DAI)? amount : getDaiAmountFromDUSD(amount);
    
    uint256 aDaiBalance = aArbDAI.scaledBalanceOf(address(this));
    uint256 amountWithdraw = aavePool.withdraw(address(DAI), amountInDai, address(this));
    uint256 subAmount = aDaiBalance - aArbDAI.scaledBalanceOf(address(this));
    
    require(scaledBalances[msg.sender] >= subAmount, "Exceeds max withdrawal amount");
    uint256 daiSubAmount = daiBalances[msg.sender] * subAmount / scaledBalances[msg.sender];
    scaledBalances[msg.sender] = scaledBalances[msg.sender] - subAmount;
    daiBalances[msg.sender] = daiBalances[msg.sender] - daiSubAmount;

    if(amountWithdraw > daiSubAmount) {
      uint256 reward = amountWithdraw - daiSubAmount;
      reward = collectFee(reward, msg.sender);
      DAI.safeTransfer(fluidTreasury, reward);
      amountWithdraw = amountWithdraw - reward;
    }

    if (token == address(DAI)) {
      DAI.safeTransfer(msg.sender, amountWithdraw);
    }
    else if (token == address(DUSD)) {
      amountWithdraw = balancerSwap(amountWithdraw, address(DAI), address(DUSD), msg.sender, balancerPoolId);
    }

    return amountWithdraw;
  }

  function getDaiAmountFromDUSD(uint256 amount) public returns (uint256) {
    IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](1);
    swaps[0] = IBalancerVault.BatchSwapStep(balancerPoolId, 0, 1, amount, "");
    address[] memory tokens = new address[](2);
    tokens[0] = address(DAI);
    tokens[1] = address(DUSD);

    int256[] memory assetDeltas = new int256[](2);
    assetDeltas = balancerVault.queryBatchSwap(
      IBalancerVault.SwapKind.GIVEN_OUT,
      swaps,
      tokens,
      IBalancerVault.FundManagement(address(this), true, payable(address(this)), false)
    );
    return uint256(assetDeltas[0]);
  }

  function collectFee(uint256 amount, address addr) private view returns (uint256) {
    uint256 fee = feeTiers[0];
    uint256 balance = FLUID.balanceOf(addr);
    for (uint256 i = 0; i <= 3; i++) {
      if (balance >= fluidTiers[i] * 10**18) {
        fee = feeTiers[i];
      }
    }
    uint256 feeAmount = amount * fee / 10000;
    return feeAmount;
  }
}