//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "./interface/IAToken.sol";
import "./interface/IAavePool.sol";
import "./interface/IBalancerVault.sol";

contract AaveVaultUpgradable is Initializable,ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using AddressUpgradeable for address;
  using FixedPointMathLib for uint256;

  uint256 public constant MAX_INT = 2**256 - 1;
  IERC20Upgradeable public DUSD;
  IERC20Upgradeable public DAI;
  IERC20Upgradeable public FLUID;
  IAToken public aArbDAI;
  address public tokenTransferProxy;
  address public augustus;
  IAavePool public aavePool;
  IBalancerVault public balancerVault;
  bytes32 public balancerPoolId;
  address public fluidTreasury;
  uint256[] public fluidTiers;
  uint256[] public feeTiers;
  mapping(address => uint256) public daiBalances;

  // @notice Emitted after successful Deposit
  // @param token The address of the token dposited
  // @param amount The amounf of token that is deposited
  // @param reciever The address that got the Vault shares
  event Deposit(address token, uint256 amount ,address reciever);

  // @notice Emitted after successful Withdraw
  // @param token The address of the token Withdrawn
  // @param amount The amounf of token that is Withdrawn
  // @param reciever The address that got the withdrawn tokens
  event Withdraw(address token, uint256 amount, address reciever);

  function initialize(
    address _dusd, 
    address _dai, 
    address _fluid, 
    address _aArbDai,
    address _tokenTransferProxy, 
    address _augustusAddr, 
    address _aavePool, 
    address _fluidTreasury, 
    address _balancerVault, 
    bytes32 _balancerPoolId
  ) public initializer {
    __Ownable_init();
    __ERC20_init("FluidAaveVault", "FAV");
    DUSD = IERC20Upgradeable(_dusd);
    DAI = IERC20Upgradeable(_dai);
    FLUID = IERC20Upgradeable(_fluid);
    aArbDAI = IAToken(_aArbDai);
    tokenTransferProxy = _tokenTransferProxy;
    augustus = _augustusAddr;
    aavePool = IAavePool(_aavePool);
    fluidTreasury = _fluidTreasury;
    balancerVault = IBalancerVault(_balancerVault);
    balancerPoolId = _balancerPoolId;
    fluidTiers = [0, 1000, 10000, 50000, 150000];
    feeTiers = [2000, 1500, 1300, 1200, 1000];
  }

  
  // @notice Returns the total amount of arbDAI the vault holds
  function totalAssets() public view returns (uint256) {
    // aTokens use rebasing to accrue interest, so the total assets is just the aToken balance
    return aArbDAI.balanceOf(address(this));
  }
  
  // @notice Deposit DUSD or DAI to aave
  // @dev Uses Paraswap to do the (DUSD or DAI) --> arbDAI swap
  // @param token The token address can only be DUSD or DAI
  // @param amount The amount of token, that you want to deposit
  // @param swapCalldata This is the data needed to perform the swap through paraswap and is fetchd through their apis
  function deposit(
    address token, 
    uint256 amount, 
    bytes memory swapCalldata
  ) public nonReentrant returns(uint256 shares) {
    require(token == address(DUSD) || token == address(DAI), "Not allowed token deposited");
    uint256 totalAsset = totalAssets();
    IERC20Upgradeable(token).safeTransferFrom(msg.sender, address(this), amount);
    IERC20Upgradeable(token).safeApprove(tokenTransferProxy, amount);
    uint256 originalDaiBalance = DAI.balanceOf(address(aArbDAI));
    callParaswap(swapCalldata);
    uint256 assets = DAI.balanceOf(address(aArbDAI)) - originalDaiBalance;
	  daiBalances[msg.sender] += assets;
    require((shares = previewDeposit(assets, totalAsset)) != 0, "ZERO_SHARES");
    _mint(msg.sender, shares);
    emit Deposit(token, amount, msg.sender);
  }
  
  // @notice Withdraw All the deposit at once
  // @dev Uses balancer pool to do the DAI to DUSD swap if required
  // @param token The token address the you want withdrawl in, can only be DUSD or DAI
  // @return amountWithdrawn The amount of toke withdraw from the vault
  function withdraw(address token) public nonReentrant returns(uint256 amountWithdrawn) {
    require(token == address(DUSD) || token == address(DAI), "Not allowed token deposited");
    uint256 amountDeposited = maxWithdraw(msg.sender);
    amountWithdrawn = aavePool.withdraw(address(DAI), amountDeposited, address(this));
    
    // If the user had a profit throught the vault, take the reward fees. 
    if(amountWithdrawn > amountDeposited) {
      uint256 reward = amountWithdrawn - amountDeposited;
      reward = collectFee(reward, msg.sender);
      DAI.safeTransfer(fluidTreasury, reward);
      amountWithdrawn = amountWithdrawn - reward;
    }

    if (token == address(DAI)) {
      DAI.safeTransfer(msg.sender, amountWithdrawn);
    }else if (token == address(DUSD)) {
      // If the withdrawl token is DUSD, make the swap from DAI -> DUSD
      amountWithdrawn = balancerSwap(amountWithdrawn, address(DAI), address(DUSD), msg.sender, balancerPoolId);
    }
    _burn(msg.sender, maxRedeem(msg.sender));
    emit Withdraw(token, amountWithdrawn, msg.sender);
  }

  // @notice Calculates fees for the user based on its fluid token holdings
  // @param amount The amount that needs to be taxed
  // @param addr The addr for which the fees is getting calculated
  // @return feeAmount The amount of fees that will be applied on the withdrawl
  function collectFee(uint256 amount, address addr) private view returns (uint256 feeAmount) {
    uint256 fee;
    uint256 balance = FLUID.balanceOf(addr);
    for (uint256 i = 0; i <= 4; ) {
      if (balance >= fluidTiers[i] * 10**18) {
        fee = feeTiers[i];
      }
      unchecked {
        ++i;
      }
    }
    feeAmount = amount * fee / 10000;
  }

  // @motice This is used to make the swap from one token to another through paraswap
  // @dev The swapCalldata is fetched from paraswap API
  // @param swapCalldata The calldata needed to perform the appropriate swap
  function callParaswap(bytes memory swapCalldata) internal {
    (bool success,) = augustus.call(swapCalldata);

    if (!success) {
      // Copy revert reason from call
      assembly {
          returndatacopy(0, 0, returndatasize())
          revert(0, returndatasize())
      }
    }
  }

  // @notice This function is used to swap between DUSD <-> DAI through balancer pool
  // @dev This function is used at the time withdrawl to swap DAI --> DUSD if required
  // @param amount The amount of assetIn that needs to be swapped
  // @param assetIn The address of source token
  // @param assetOut The address of destination token
  // @param @recipient The address that will be given the swapped token
  // @param @poolId This is the poolId of DUSD <-> DAI pool
  // @return 
  function balancerSwap(
    uint256 amount, 
    address assetIn, 
    address assetOut, 
    address recipient, 
    bytes32 poolId
  ) internal returns (uint256) {
    IERC20Upgradeable(assetIn).safeApprove(address(balancerVault), amount);
    bytes memory userData = "";
    uint256 value = balancerVault.swap(
      IBalancerVault.SingleSwap(poolId, IBalancerVault.SwapKind.GIVEN_IN, assetIn, assetOut, amount, userData),
      IBalancerVault.FundManagement(address(this), true, payable(recipient), false),
      0,
      MAX_INT
    );
    return value;
  }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/


    function convertToShares(uint256 assets, uint256 totalAsset) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAsset);
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function previewDeposit(uint256 assets, uint256 totalAsset) public view virtual returns (uint256) {
        return convertToShares(assets, totalAsset);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxWithdraw(address _addr) public view returns (uint256) {
        return convertToAssets(balanceOf(_addr));
    }
    function maxRedeem(address _addr) public view virtual returns (uint256) {
        return balanceOf(_addr);
    }

  /*//////////////////////////////////////////////////////////////
                          Owner Only Functions 
    //////////////////////////////////////////////////////////////*/
  function setTreasuryAddress(address _fluidTreasury) public onlyOwner {
    fluidTreasury = _fluidTreasury;
  }
  
  function setFeeFluidTier(uint256 _index, uint256 _fluidAmount) public onlyOwner {
    fluidTiers[_index] = _fluidAmount;
  }

  function setFee(uint256 _index, uint256 _fee) public onlyOwner {
    require(_fee <= 10000, "Exceeds maximum fee");
    feeTiers[_index] = _fee;
  }

  function emergencyTransferTokens(address tokenAddress, address to, uint256 amount) public onlyOwner {
    require(tokenAddress != address(DUSD), "Not allowed to withdraw deposited token");
    require(tokenAddress != address(DAI), "Not allowed to withdraw reward token");
    
    IERC20Upgradeable(tokenAddress).safeTransfer(to, amount);
  }

  function emergencyTransferETH(address payable recipient) public onlyOwner {
    AddressUpgradeable.sendValue(recipient, address(this).balance);
  }
}
