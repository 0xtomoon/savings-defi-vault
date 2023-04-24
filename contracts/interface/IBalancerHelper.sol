// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import "./IBalancerVault.sol";

interface IBalancerHelper {
	function queryExit(
		bytes32 poolId,
		address sender,
		address payable recipient,
		IBalancerVault.ExitPoolRequest memory request
	) external returns(uint256, uint256[] memory);
}