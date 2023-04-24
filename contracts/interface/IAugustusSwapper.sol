//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAugustusSwapper {

  struct Route {
    address payable exchange;
    address targetExchange;
    uint percent;
    bytes payload;
    uint256 networkFee;//Network fee is associated with 0xv3 trades
  }

  struct Path {
    address to;
    uint256 totalNetworkFee;//Network fee is associated with 0xv3 trades
    Route[] routes;
  }

  function getPartnerRegistry() external view returns(address);

  function getWhitelistAddress() external view returns(address);

  function getFeeWallet() external view returns(address);

  function getTokenTransferProxy() external view returns (address);

  function paused() external view returns (bool);

  /**
 * @dev The function which performs the multi path swap.
 * @param fromToken Address of the source token
 * @param toToken Address of the destination token
 * @param fromAmount Amount of source tokens to be swapped
 * @param toAmount Minimum destination token amount expected out of this swap
 * @param expectedAmount Expected amount of destination tokens without slippage
 * @param path Route to be taken for this swap to take place
 * @param mintPrice Price of gas at the time of minting of gas tokens, if any. In wei. 0 means gas token will not be used
 * @param beneficiary Beneficiary address
 * @param donationPercentage Percentage of returned amount to be transferred to beneficiary, if beneficiary is available. If this is passed as
 * 0 then 100% will be transferred to beneficiary. Pass 10000 for 100%
 * @param referrer referral id
 */
  function multiSwap(
    IERC20 fromToken,
    IERC20 toToken,
    uint256 fromAmount,
    uint256 toAmount,
    uint256 expectedAmount,
    Path[] calldata path,
    uint256 mintPrice,
    address payable beneficiary,
    uint256 donationPercentage,
    string calldata referrer
  )
  external
  payable
  returns (uint256);
}
