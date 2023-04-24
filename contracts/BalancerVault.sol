//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import "./interface/IBalancerVault.sol";
import "./interface/IBalancerHelper.sol";
import "hardhat/console.sol";


library Balancer {
  function balancerJoinPool(
    IBalancerVault balancerVault, 
    address[] memory tokens, 
    uint256[] memory maxAmountsIn, 
    bytes32 poolId
  ) internal {
    bytes memory userData = abi.encode(1, maxAmountsIn, 0); // JoinKind: 1
    balancerVault.joinPool(
      poolId,
      address(this),
      address(this),
      IBalancerVault.JoinPoolRequest(
        tokens, 
        maxAmountsIn, 
        userData, 
        false
      )
    );
  }
  function balancerCustomExitPool(
    IBalancerVault balancerVault, 
    address[] memory tokens, 
    uint256[] memory minAmountsOut, 
    bytes32 poolId,
    bytes memory userData
  ) internal {
    balancerVault.exitPool(
      poolId,
      address(this),
      payable(address(this)),
      IBalancerVault.ExitPoolRequest(
        tokens, 
        minAmountsOut, 
        userData, 
        false
      )
    );
  }
    function balancerQueryExit(
      IBalancerHelper balancerHelper, 
      address[] memory tokens, 
      uint256[] memory minAmountsOut,
      bytes32 poolId, uint256 bptAmountIn, 
      uint256 tokenIndex
    ) internal returns (uint256) {
    uint256[] memory amountsOut;
    (, amountsOut) = balancerHelper.queryExit(
      poolId,
      address(this),
      payable(address(this)),
      IBalancerVault.ExitPoolRequest(
        tokens, 
        minAmountsOut, 
        abi.encode(
          BalancerVaultUpgradable.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, 
          bptAmountIn, 
          tokenIndex
        ),
        false
      )
    );
    return amountsOut[tokenIndex];
  }

  function balancerSwapOut(
    IBalancerVault balancerVault,
    IBalancerVault.SwapKind swap,
    BalancerVaultUpgradable.BalancerSwapParam memory param
  ) internal returns (uint256) {
    IERC20Upgradeable(param.assetIn).approve(address(balancerVault), param.amount);
    return balancerVault.swap(
      IBalancerVault.SingleSwap(
        param.poolId, 
        swap, 
        param.assetIn, 
        param.assetOut, 
        param.amount, 
        ""
      ),
      IBalancerVault.FundManagement(
        address(this), 
        true, 
        payable(param.recipient), 
        false
      ),
      param.maxAmountIn,
      2**256 - 1
    );
  }
}



contract BalancerVaultUpgradable is Initializable,ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using AddressUpgradeable for address;

  uint256 public constant MAX_INT = 2**256 - 1;
  IERC20Upgradeable public DUSD;
  IERC20Upgradeable public DAI;
  IERC20Upgradeable public FLUID;
  IERC20Upgradeable public DUSDDAI_POOL;
  address public fluidTreasury;
  IBalancerVault public balancerVault;
  IBalancerHelper public balancerHelper;
  bytes32 public balancerPoolId;
  uint256[] public fluidTiers;
  uint256[] public feeTiers;
  address[] tokens;
    

  struct DepositInfo {
    uint256 poolBalance;
    uint256 depositAmount;
    address depositToken;
  }

  mapping(address => DepositInfo) public depositBalances;

  enum ExitKind { EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, EXACT_BPT_IN_FOR_TOKENS_OUT, BPT_IN_FOR_EXACT_TOKENS_OUT }

  struct BalancerSwapParam {
    uint256 amount;
    address assetIn;
    address assetOut;
    address recipient;
    bytes32 poolId;
    uint256 maxAmountIn;
  }

  // @notice Emitted after successful Deposit
  // @param token The address of the token deposited
  // @param amount The amount of token that is deposited
  // @param reciever The address that got the Vault shares
  event Deposit(address token, uint256 amount ,address reciever);

  // @notice Emitted after successful Withdraw
  // @param token The address of the token Withdrawn
  // @param amount The amount of token that is Withdrawn
  // @param reciever The address that got the withdrawn tokens
  event Withdraw(address token, uint256 amount, address reciever);

  error ZeroAmount();
  error TokenNotAllowed();
  error ExceedMaximumFee();
  error NoDeposit();

  function _checkToken(address token) internal view {
      if(
      token != address(DUSD) && 
      token != address(DAI) && 
      token != address(DUSDDAI_POOL)
      ) revert TokenNotAllowed();
   }
  function _checkAmount(uint256 amount) internal pure {
    if(amount == 0) revert ZeroAmount();
  }
  function initialize(
    address _dusd, 
    address _dai, 
    address _fluid, 
    address _fluidTreasury, 
    address _balancerVault, 
    address _balancerHelper, 
    bytes32 _balancerPoolId, 
    address _dusdDaiPool
  ) public initializer {
    __Ownable_init();
    __ERC20_init("FluidBalancerVault", "FBV");
    DUSD = IERC20Upgradeable(_dusd);
    DAI = IERC20Upgradeable(_dai);
    FLUID = IERC20Upgradeable(_fluid);
    fluidTreasury = _fluidTreasury;
    balancerVault = IBalancerVault(_balancerVault);
    balancerHelper = IBalancerHelper(_balancerHelper);
    balancerPoolId = _balancerPoolId;
    DUSDDAI_POOL = IERC20Upgradeable(_dusdDaiPool);
    fluidTiers = [0, 1000, 10000, 50000, 150000];
    feeTiers = [2000, 1500, 1300, 1200, 1000];
    tokens = new address[](2);
    tokens[0] = address(DAI);
    tokens[1] = address(DUSD);
    
  }

  function setTreasuryAddress(address _fluidTreasury) public onlyOwner {
    fluidTreasury = _fluidTreasury;
  }
  
  function setFeeFluidTier(uint256 _index, uint256 _fluidAmount) public onlyOwner {
    fluidTiers[_index] = _fluidAmount;
  }

  function setFee(uint256 _index, uint256 _fee) public onlyOwner {
    if(_fee > 10000) revert ExceedMaximumFee();
    feeTiers[_index] = _fee;
  }

  // @notice Deposit DUSD or DAI to balancer
  // @param token The token address can only be DUSD or DAI
  // @param amount The amount of token, that you want to deposit
  function deposit(address token, uint256 amount) public nonReentrant {
    _checkToken(token);
    _checkAmount(amount);
    DepositInfo memory depositInfo = depositBalances[msg.sender];
    IERC20Upgradeable(token).transferFrom(msg.sender, address(this), amount);
  
    if(token == address(DUSDDAI_POOL)){

      if(depositInfo.depositToken == address(0)) {
        depositInfo.depositToken = address(DAI);
      }
      depositInfo.poolBalance = depositInfo.poolBalance + amount;
      depositInfo.depositAmount += getTokenAmountFromBPT(depositInfo.depositToken, amount);
      
    } else { 

      IERC20Upgradeable(token).approve(address(balancerVault), amount);

      uint256[] memory maxAmountsIn = new uint256[](2);
      maxAmountsIn[0] = token == address(DAI) ? amount : 0;
      maxAmountsIn[1] = token == address(DUSD) ? amount : 0;
      
      uint256 originalBalance = DUSDDAI_POOL.balanceOf(address(this));
      bytes memory userData = abi.encode(1, maxAmountsIn, 0); // JoinKind: 1
      balancerVault.joinPool(
        balancerPoolId,
        address(this),
        address(this),
        IBalancerVault.JoinPoolRequest(
          tokens, 
          maxAmountsIn, 
          userData, 
          false
        )
      );

      uint256 bptAmount = DUSDDAI_POOL.balanceOf(address(this)) - originalBalance;

      depositInfo.poolBalance += bptAmount;

      _mint(msg.sender, bptAmount);
            
      if(depositInfo.depositToken == address(0)) { // first deposit
        depositInfo.depositToken = token;
      }
      
      if(depositInfo.depositToken != token) { 
        depositInfo.depositAmount += getTokenAmountFromBPT(depositInfo.depositToken, bptAmount);
      }else{
        depositInfo.depositAmount += amount;
      }
    }
    depositBalances[msg.sender] = depositInfo;
    emit Deposit(token, amount, msg.sender);
  }

  // @notice Withdraw fixed amount from vault
  // @param token The token address the you want withdrawl in, can only be DUSD or DAI
  // @param amount The amount of token that you want to writhdraw
  // @return amountWithdrawn The amount of toke withdraw from the vault
  function withdraw(address token, uint256 amount) public nonReentrant{
    /*
      * burn bpt to get the desired tokens
      * check if the token returned is deposit token
      * if yes take the fees and give user the token
      * if no take the fees and give user the swapped token
     */
    
    _checkToken(token);
    _checkAmount(amount);
    
    DepositInfo memory depositInfo = depositBalances[msg.sender];

    if(depositInfo.depositToken == address(0)) revert NoDeposit();

    DUSDDAI_POOL.approve(address(balancerVault), depositInfo.poolBalance);
  
    address depositToken = depositInfo.depositToken;

    uint256[] memory minAmountsOut = new uint256[](2);
    uint256[] memory amountsOut = new uint256[](2);
    amountsOut[0] = depositToken == address(DAI) ? amount : 0;
    amountsOut[1] = depositToken == address(DUSD) ? amount : 0;
    uint256 bptAmount;
    {
      uint256 originalBalance = IERC20Upgradeable(DUSDDAI_POOL).balanceOf(address(this));
      bytes memory userData = abi.encode(
          ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT, 
          amountsOut, 
          depositInfo.poolBalance
        );

      // burn bpt & get the desired token
      Balancer.balancerCustomExitPool(
        balancerVault, 
        tokens, 
        minAmountsOut, 
        balancerPoolId, 
        userData
      );
      bptAmount = originalBalance - IERC20Upgradeable(DUSDDAI_POOL).balanceOf(address(this));
    }
    _burn(msg.sender, bptAmount);

    uint256 depositSubAmount = depositInfo.depositAmount * bptAmount / depositInfo.poolBalance;
    _withdraw(
      depositSubAmount,
      amount,
      token,
      depositToken
    );

    depositBalances[msg.sender].depositAmount -= depositSubAmount;
    depositBalances[msg.sender].poolBalance -= bptAmount;
    emit Withdraw(token, amount, msg.sender);
  }
  
  // @notice Withdraw All the deposit at once
  // @param token The token address the you want withdrawl in, can only be DUSD or DAI
  // @return amountWithdrawn The amount of token to withdraw from the value
  function withdrawAll(address token) public  nonReentrant returns(uint256 amountWithdraw) {
    _checkToken(token);
    DepositInfo memory depositInfo = depositBalances[msg.sender];
    if(depositInfo.depositToken == address(0)) revert NoDeposit();
    DUSDDAI_POOL.approve(address(balancerVault), depositInfo.poolBalance);

    uint256[] memory minAmountsOut = new uint256[](2);
    uint256 tokenIndex = depositInfo.depositToken == address(DAI) ? 0 : 1;

    uint256 originalBalance = IERC20Upgradeable(depositInfo.depositToken).balanceOf(address(this));
    bytes memory userData = abi.encode(
          BalancerVaultUpgradable.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, 
          depositInfo.poolBalance, 
          tokenIndex
    );
    Balancer.balancerCustomExitPool(
      balancerVault, 
      tokens, 
      minAmountsOut, 
      balancerPoolId, 
      userData
    );
    amountWithdraw = IERC20Upgradeable(depositInfo.depositToken).balanceOf(address(this)) - originalBalance;

    _burn(msg.sender, balanceOf(msg.sender));
    _withdraw(
      depositInfo.depositAmount,
      amountWithdraw,
      token,
      depositInfo.depositToken
    );

    depositInfo.depositToken = address(0);
    depositInfo.depositAmount = 0;
    depositInfo.poolBalance = 0;
    depositBalances[msg.sender] = depositInfo;
    emit Withdraw(token, amountWithdraw, msg.sender);
  }

 function _withdraw(
  uint256 amountDeposited,
  uint256 amountWithdrawn,
  address token,
  address depositToken
 ) internal {
  // transfer fees to treasury
  if(amountWithdrawn > amountDeposited){
    uint256 fee = collectFee(amountWithdrawn - amountDeposited, msg.sender);
    _transferVaultTokens(depositToken, fluidTreasury, fee);
    amountWithdrawn -= fee;
  }

  if(token == depositToken){
     _transferVaultTokens(token,msg.sender, amountWithdrawn);
  }else{
    amountWithdrawn -= Balancer.balancerSwapOut(
      balancerVault, 
      IBalancerVault.SwapKind.GIVEN_IN, 
      BalancerSwapParam(
        amountWithdrawn, 
        depositToken, 
        token, 
        msg.sender, 
        balancerPoolId, 
        amountWithdrawn
      )
    );
  }
 }
 
 function _transferVaultTokens(address token, address recipient, uint256 amount) internal{
  IERC20Upgradeable(token).transfer(recipient, amount);
 }
 function collectFee(uint256 amount, address addr) internal view returns (uint256 feeAmount) {
    uint256 fee;
    uint256 balance = FLUID.balanceOf(addr);
    for (uint256 i; i <= 4; ) {
      if (balance >= fluidTiers[i] * 10**18) {
        fee = feeTiers[i];
      }
      unchecked {
        ++i;
      }
    }
    feeAmount = amount * fee / 10000;
  }

  
  /// static calling this function
  
  function userReward(address token, address _addr) public returns (uint256 profit) {
    uint256 bptBalance = depositBalances[_addr].poolBalance;
    uint256 depositAmount = depositBalances[_addr].depositAmount;
    address depositToken = depositBalances[_addr].depositToken;
    uint256 tokenWithdrawalAmount = getTokenAmountFromBPT(token, bptBalance);

    if(tokenWithdrawalAmount > depositAmount) {
      profit = tokenWithdrawalAmount - depositAmount;
      if(token == depositToken) return profit;

      uint256 profitInBpt = profit * bptBalance / tokenWithdrawalAmount;
      profit = getTokenAmountFromBPT(token, profitInBpt);
    }
  }

  function getTokenAmountFromBPT(
    address tokenOut, 
    uint256 bptAmountIn
  ) public returns (uint256 tokenWithdrawalAmount) {
    uint256[] memory minAmountsOut = new uint256[](2);
    uint256 tokenIndex = tokenOut == address(DAI) ? 0 : 1;
    tokenWithdrawalAmount = Balancer.balancerQueryExit(
      balancerHelper, 
      tokens, 
      minAmountsOut, 
      balancerPoolId, 
      bptAmountIn, 
      tokenIndex
    );
  }
  


  function emergencyTransfer(address token, address to, uint256 amount) public onlyOwner {
    if(token == address(0)){
      AddressUpgradeable.sendValue(payable(to), address(this).balance);
    }else{
      IERC20Upgradeable(token).transfer(to, amount);
    }
  }
}

