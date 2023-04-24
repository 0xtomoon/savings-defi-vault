// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAToken is IERC20 {
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
	function scaledBalanceOf(address user) external view returns (uint256);
}