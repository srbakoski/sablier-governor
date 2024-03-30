// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Timelock is TimelockController {
	// Admin is set to address(0) so there is no account with privileges
	constructor(
		uint256 minDelay,
		address[] memory proposers,
		address[] memory executors,
		address admin
	) TimelockController(minDelay, proposers, executors, admin) {}
}
