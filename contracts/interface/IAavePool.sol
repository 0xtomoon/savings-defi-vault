// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import "../libraries/DataTypes.sol";

interface IAavePool {
	function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
	function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
	function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}